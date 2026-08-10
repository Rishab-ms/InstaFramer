import 'dart:ui' show Color;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/enums.dart';
import '../../models/panorama_settings.dart';
import '../../models/panorama_spec.dart';
import '../../services/export_service.dart';
import '../../services/image_processor.dart';
import '../../services/preferences_service.dart';
import 'panorama_event.dart';
import 'panorama_state.dart';

/// BLoC for managing the panorama-carousel selection and editing workflow.
///
/// Deliberately separate from [PhotoBloc] rather than an extension of it.
/// See the "Architecture" section of the panorama plan. Shares
/// [ExportService] and [PreferencesService] with the framer, but owns no
/// mutable state in common with it.
class PanoramaBloc extends Bloc<PanoramaEvent, PanoramaState> {
  final ExportService _exportService;
  final PreferencesService _preferencesService;
  final ImageProcessor _imageProcessor;

  PanoramaBloc({
    required ExportService exportService,
    required PreferencesService preferencesService,
    ImageProcessor? imageProcessor,
  }) : _exportService = exportService,
       _preferencesService = preferencesService,
       _imageProcessor = imageProcessor ?? ImageProcessor(),
       super(const PanoramaInitialState()) {
    on<PanoramaSourceSelectedEvent>(_onPanoramaSourceSelected);
    on<UpdateTileCountEvent>(_onUpdateTileCount);
    on<UpdateFitModeEvent>(_onUpdateFitMode);
    on<UpdatePanoramaScaleEvent>(_onUpdatePanoramaScale);
    on<UpdatePanoramaBackgroundTypeEvent>(_onUpdatePanoramaBackgroundType);
    on<UpdatePanoramaBackgroundColorEvent>(_onUpdatePanoramaBackgroundColor);
    on<UpdatePanoramaBlurIntensityEvent>(_onUpdatePanoramaBlurIntensity);
    on<UpdatePanoramaTileRatioEvent>(_onUpdatePanoramaTileRatio);
    on<UpdatePanoramaCornerRadiusEvent>(_onUpdatePanoramaCornerRadius);
    on<UpdatePanoramaCropOffsetXEvent>(_onUpdatePanoramaCropOffsetX);
    on<UpdatePanoramaCropOffsetYEvent>(_onUpdatePanoramaCropOffsetY);
    on<ClearPanoramaEvent>(_onClearPanorama);
    on<ExportPanoramaEvent>(_onExportPanorama);
    on<DismissPanoramaErrorEvent>(_onDismissPanoramaError);
  }

  /// Evaluates the picked source against `PanoramaSpec.evaluate` and emits
  /// [PanoramaReadyState] or [PanoramaIneligibleState].
  ///
  /// Uses `orientatedWidth`/`orientatedHeight` rather than raw `width`/
  /// `height`: an EXIF-rotated wide photo reports portrait dimensions on
  /// Android and would be wrongly rejected otherwise.
  Future<void> _onPanoramaSourceSelected(
    PanoramaSourceSelectedEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    final source = event.source;
    final sourceWidth = source.orientatedWidth;
    final sourceHeight = source.orientatedHeight;

    final eligibility = PanoramaSpec.evaluate(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      tileRatio: PanoramaTileRatio.portrait.ratio,
    );

    if (!eligibility.isEligible) {
      emit(PanoramaIneligibleState(eligibility.reason!));
      return;
    }

    final prefs = await _preferencesService.loadPreferences();

    // Best-effort: a thumbnail read or decode failure shouldn't block opening
    // the editor. It just leaves the color chips absent instead of populated.
    var suggestedColors = const <Color>[];
    try {
      final thumbnailBytes = await source.thumbnailDataWithSize(
        const ThumbnailSize(1200, 1200),
      );
      if (thumbnailBytes != null) {
        suggestedColors = await _imageProcessor.extractPaletteColors(
          thumbnailBytes,
        );
      }
    } catch (_) {
      // Background selector just shows no chips.
    }

    // ⚠️ The photo opens centred on both axes, always. There is machinery to
    // pick a starting horizontal position automatically. See
    // `PanoramaSeams`: and it is deliberately not called here. An
    // auto-chosen offset lands the photo off centre with uneven bars on the
    // first frame the user ever sees, which reads as a rendering fault rather
    // than a considered choice, and it does so to solve a problem the user
    // has not looked for yet. Positioning is theirs to drive; centred is the
    // only defensible opening state. See `PanoramaSeams` for the full note
    // before wiring any of it back up.
    //
    // Scale likewise starts at PanoramaSettings.defaultScale rather than
    // `prefs.lastUsedScale`: that preference belongs to the framer, where
    // insetting a photo is the feature, and a panorama opening at someone's
    // remembered 50% shows a small photo marooned in background bars. Blur
    // intensity is a genuine cross-feature taste and stays shared.
    final settings = PanoramaSettings(
      tileCount: eligibility.suggestedTiles,
      blurIntensity: prefs.lastUsedBlurIntensity,
    );

    emit(
      PanoramaReadyState(
        source: source,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        maxTiles: eligibility.maxTiles,
        settings: settings,
        suggestedColors: suggestedColors,
      ),
    );
  }

  /// Clamps both position offsets to what the current framing can reach.
  ///
  /// Every setting that changes the canvas shape or the photo's size within it
  ///. Tile count, tile ratio, fit mode, zoom. Also changes how far the photo
  /// can slide on each axis. An offset chosen against the old framing may now
  /// be unreachable, and *storing* an unreachable offset is what made the
  /// slider read -50% while the render honoured -14%.
  ///
  /// A clamp and nothing more: the user's position is never recomputed or
  /// second-guessed, only kept inside what the renderer will honour.
  PanoramaSettings _reconcileOffsets(
    PanoramaSettings settings, {
    required double sourceAspect,
  }) {
    final canvasRatio = PanoramaSpec.canvasRatio(
      settings.tileCount,
      settings.tileRatio.ratio,
    );

    final maxX = PanoramaSpec.maxCropOffsetX(
      tileCount: settings.tileCount,
      fitMode: settings.fitMode,
      scale: settings.scale,
      sourceAspect: sourceAspect,
      canvasRatio: canvasRatio,
    );
    final maxY = PanoramaSpec.maxCropOffsetY(
      tileCount: settings.tileCount,
      fitMode: settings.fitMode,
      sourceAspect: sourceAspect,
      canvasRatio: canvasRatio,
    );

    return settings.copyWith(
      cropOffsetX: settings.cropOffsetX.clamp(-maxX, maxX),
      cropOffsetY: settings.cropOffsetY.clamp(-maxY, maxY),
    );
  }

  // The five settings handlers below all guard on `state is
  // PanoramaReadyState` and no-op otherwise. Mirrors PhotoBloc's handlers.
  // These events can only be dispatched from PanoramaEditorScreen, which is
  // only reachable once the bloc is already in PanoramaReadyState, so the
  // guard is a defensive no-op in practice, not a reachable branch.

  Future<void> _onUpdateTileCount(
    UpdateTileCountEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = _reconcileOffsets(
      currentState.settings.copyWith(tileCount: event.tileCount),
      sourceAspect: currentState.sourceAspect,
    );
    emit(currentState.copyWith(settings: updatedSettings));
  }

  Future<void> _onUpdateFitMode(
    UpdateFitModeEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = _reconcileOffsets(
      currentState.settings.copyWith(fitMode: event.fitMode),
      sourceAspect: currentState.sourceAspect,
    );
    emit(currentState.copyWith(settings: updatedSettings));
  }

  /// Updates zoom.
  ///
  /// Deliberately does **not** persist to `lastUsedScale`, unlike
  /// `PhotoBloc._onUpdateScale`. Zooming a panorama out is a per-photo
  /// composition choice, not a standing preference, and writing it to the
  /// shared key would push it onto the framer as well. The leak that made
  /// panoramas open at whatever inset the padding editor was last left at.
  ///
  /// Zoom is a framing change like any other: it resizes the photo inside the
  /// canvas, which moves every seam across it *and* changes how far the photo
  /// can slide, so the seam offset has to be reconciled here too.
  Future<void> _onUpdatePanoramaScale(
    UpdatePanoramaScaleEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = _reconcileOffsets(
      currentState.settings.copyWith(scale: event.scale),
      sourceAspect: currentState.sourceAspect,
    );
    emit(currentState.copyWith(settings: updatedSettings));
  }

  Future<void> _onUpdatePanoramaBackgroundType(
    UpdatePanoramaBackgroundTypeEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = currentState.settings.copyWith(
      backgroundType: event.backgroundType,
      // White/Black/Blur is mutually exclusive with a picked photo color,
      // without clearing this, the renderer (which checks backgroundColor
      // first) would keep showing the old color instead of the newly picked
      // type.
      clearBackgroundColor: true,
    );
    emit(currentState.copyWith(settings: updatedSettings));
  }

  /// Picks a solid color from the photo's own suggested palette. See
  /// `plans/color_picking.md`. Overrides `backgroundType` until white/black/
  /// blur is picked again.
  Future<void> _onUpdatePanoramaBackgroundColor(
    UpdatePanoramaBackgroundColorEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = currentState.settings.copyWith(
      backgroundColor: event.color,
    );
    emit(currentState.copyWith(settings: updatedSettings));
  }

  /// Updates blur intensity and persists to `lastUsedBlurIntensity`,
  /// mirroring `PhotoBloc._onUpdateBlurIntensity`.
  Future<void> _onUpdatePanoramaBlurIntensity(
    UpdatePanoramaBlurIntensityEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = currentState.settings.copyWith(
      blurIntensity: event.intensity,
    );
    emit(currentState.copyWith(settings: updatedSettings));

    final prefs = await _preferencesService.loadPreferences();
    await _preferencesService.savePreferences(
      prefs.copyWith(lastUsedBlurIntensity: event.intensity),
    );
  }

  /// Updates the per-tile aspect ratio. Switching ratio changes the canvas
  /// shape for the same tile count, so the current count can go from a good
  /// fit to mostly-empty tiles. Kept as-is when it still covers well,
  /// otherwise snapped to the freshly suggested count for the new ratio.
  Future<void> _onUpdatePanoramaTileRatio(
    UpdatePanoramaTileRatioEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final settings = currentState.settings;
    final newRatio = event.tileRatio.ratio;

    final stillFits = PanoramaSpec.emptyTiles(
      tileCount: settings.tileCount,
      fitMode: settings.fitMode,
      scale: settings.scale,
      cropOffsetX: settings.cropOffsetX,
      sourceAspect: currentState.sourceAspect,
      canvasRatio: PanoramaSpec.canvasRatio(settings.tileCount, newRatio),
    ).isEmpty;

    final tileCount = stillFits
        ? settings.tileCount
        : PanoramaSpec.suggestedTileCount(
            maxTiles: currentState.maxTiles,
            fitMode: settings.fitMode,
            scale: settings.scale,
            sourceAspect: currentState.sourceAspect,
            tileRatio: newRatio,
          );

    final updatedSettings = _reconcileOffsets(
      settings.copyWith(tileRatio: event.tileRatio, tileCount: tileCount),
      sourceAspect: currentState.sourceAspect,
    );
    emit(currentState.copyWith(settings: updatedSettings));
  }

  /// Updates the photo's corner-rounding amount. Purely cosmetic. Unlike
  /// tile ratio, this never changes canvas shape or tile-count validity, so
  /// no reconciliation is needed beyond a plain copyWith.
  Future<void> _onUpdatePanoramaCornerRadius(
    UpdatePanoramaCornerRadiusEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = currentState.settings.copyWith(
      cornerRadius: event.cornerRadius,
    );
    emit(currentState.copyWith(settings: updatedSettings));
  }

  /// Updates the horizontal crop position. Clamped by [_reconcileOffsets] to
  /// the travel the current framing allows.
  Future<void> _onUpdatePanoramaCropOffsetX(
    UpdatePanoramaCropOffsetXEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = _reconcileOffsets(
      currentState.settings.copyWith(cropOffsetX: event.cropOffsetX),
      sourceAspect: currentState.sourceAspect,
    );
    emit(currentState.copyWith(settings: updatedSettings));
  }

  /// Updates the vertical crop position. Clamped by [_reconcileOffsets] to
  /// the slack Fill's crop window actually has; a no-op in Fit, where the
  /// geometry pins vertical travel to zero.
  Future<void> _onUpdatePanoramaCropOffsetY(
    UpdatePanoramaCropOffsetYEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = _reconcileOffsets(
      currentState.settings.copyWith(cropOffsetY: event.cropOffsetY),
      sourceAspect: currentState.sourceAspect,
    );
    emit(currentState.copyWith(settings: updatedSettings));
  }

  Future<void> _onClearPanorama(
    ClearPanoramaEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    emit(const PanoramaInitialState());
  }

  /// Renders and saves the panorama tiles, relaying `ExportService.exportPanorama`'s
  /// two-phase progress stream as [PanoramaExportingState].
  ///
  /// ❌ Does NOT copy `PhotoBloc._onExportAllPhotos`'s
  /// `emit(error) -> delay -> emit(previous)` cycling. That's the
  /// auto-state-cycling the Development Rules forbid. On failure this emits a
  /// terminal [PanoramaErrorState] carrying `previous`; the UI decides when to
  /// return to it via [DismissPanoramaErrorEvent].
  Future<void> _onExportPanorama(
    ExportPanoramaEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    WakelockPlus.enable();

    try {
      await for (final progress in _exportService.exportPanorama(
        source: currentState.source,
        settings: currentState.settings,
      )) {
        emit(
          PanoramaExportingState(
            phase: progress.phase,
            saved: progress.saved,
            total: progress.total,
          ),
        );
      }

      emit(PanoramaExportedState(currentState.settings.tileCount));
    } catch (e) {
      emit(
        PanoramaErrorState(
          message: 'Export failed: $e',
          previous: currentState,
        ),
      );
    } finally {
      WakelockPlus.disable();
    }
  }

  Future<void> _onDismissPanoramaError(
    DismissPanoramaErrorEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaErrorState) return;
    final currentState = state as PanoramaErrorState;
    emit(currentState.previous);
  }
}
