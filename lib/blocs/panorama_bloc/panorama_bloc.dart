import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/panorama_seams.dart';
import '../../models/panorama_settings.dart';
import '../../models/panorama_spec.dart';
import '../../services/export_service.dart';
import '../../services/image_processor.dart';
import '../../services/preferences_service.dart';
import 'panorama_event.dart';
import 'panorama_state.dart';

/// BLoC for managing the panorama-carousel selection and editing workflow.
///
/// Deliberately separate from [PhotoBloc] rather than an extension of it —
/// see the "Architecture" section of the panorama plan. Shares
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
    on<UpdatePanoramaBlurIntensityEvent>(_onUpdatePanoramaBlurIntensity);
    on<UpdatePanoramaSeamOffsetEvent>(_onUpdatePanoramaSeamOffset);
    on<ResetPanoramaSeamOffsetEvent>(_onResetPanoramaSeamOffset);
    on<ResetPanoramaScaleEvent>(_onResetPanoramaScale);
    on<ClearPanoramaEvent>(_onClearPanorama);
    on<ExportPanoramaEvent>(_onExportPanorama);
    on<DismissPanoramaErrorEvent>(_onDismissPanoramaError);
  }

  /// Evaluates the picked source against `PanoramaSpec.evaluate` and emits
  /// [PanoramaReadyState] or [PanoramaIneligibleState].
  ///
  /// Uses `orientatedWidth`/`orientatedHeight` rather than raw `width`/
  /// `height` — an EXIF-rotated wide photo reports portrait dimensions on
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
    );

    if (!eligibility.isEligible) {
      emit(PanoramaIneligibleState(eligibility.reason!));
      return;
    }

    final prefs = await _preferencesService.loadPreferences();

    // Best-effort: a thumbnail read or decode failure shouldn't block
    // opening the editor — it just leaves the seam-nudge slider at its
    // centred default instead of a computed one.
    var energyProfile = const <double>[];
    try {
      final thumbnailBytes = await source.thumbnailDataWithSize(
        const ThumbnailSize(1200, 1200),
      );
      if (thumbnailBytes != null) {
        energyProfile = await _imageProcessor.computeEdgeEnergyProfile(
          thumbnailBytes,
        );
      }
    } catch (_) {
      // Keep the empty profile; _withAutoSeamOffset no-ops on it.
    }

    final settings = _withAutoSeamOffset(
      PanoramaSettings(
        tileCount: eligibility.suggestedTiles,
        scale: prefs.lastUsedScale,
        blurIntensity: prefs.lastUsedBlurIntensity,
      ),
      energyProfile: energyProfile,
      sourceAspect: sourceWidth / sourceHeight,
    );

    emit(
      PanoramaReadyState(
        source: source,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        maxTiles: eligibility.maxTiles,
        settings: settings,
        energyProfile: energyProfile,
      ),
    );
  }

  /// Recomputes `seamOffset` from a cached energy profile — shared by the
  /// initial seed on source selection and the re-optimization on tile-count
  /// / fit-mode changes, since seam positions shift with both. No-ops once
  /// `seamOffsetIsManual` is set: silently overriding a deliberate drag
  /// would be worse than a mediocre default.
  PanoramaSettings _withAutoSeamOffset(
    PanoramaSettings settings, {
    required List<double> energyProfile,
    required double sourceAspect,
  }) {
    if (settings.seamOffsetIsManual) return settings;
    return settings.copyWith(
      seamOffset: PanoramaSeams.bestSeamOffset(
        energyProfile: energyProfile,
        tileCount: settings.tileCount,
        fitMode: settings.fitMode,
        scale: settings.scale,
        sourceAspect: sourceAspect,
        canvasRatio: PanoramaSpec.canvasRatio(settings.tileCount),
      ),
    );
  }

  // The five settings handlers below all guard on `state is
  // PanoramaReadyState` and no-op otherwise — mirrors PhotoBloc's handlers.
  // These events can only be dispatched from PanoramaEditorScreen, which is
  // only reachable once the bloc is already in PanoramaReadyState, so the
  // guard is a defensive no-op in practice, not a reachable branch.

  Future<void> _onUpdateTileCount(
    UpdateTileCountEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = _withAutoSeamOffset(
      currentState.settings.copyWith(tileCount: event.tileCount),
      energyProfile: currentState.energyProfile,
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
    final updatedSettings = _withAutoSeamOffset(
      currentState.settings.copyWith(fitMode: event.fitMode),
      energyProfile: currentState.energyProfile,
      sourceAspect: currentState.sourceAspect,
    );
    emit(currentState.copyWith(settings: updatedSettings));
  }

  /// Updates scale and persists to `lastUsedScale`, mirroring
  /// `PhotoBloc._onUpdateScale`.
  Future<void> _onUpdatePanoramaScale(
    UpdatePanoramaScaleEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = currentState.settings.copyWith(scale: event.scale);
    emit(currentState.copyWith(settings: updatedSettings));

    final prefs = await _preferencesService.loadPreferences();
    await _preferencesService.savePreferences(
      prefs.copyWith(lastUsedScale: event.scale),
    );
  }

  Future<void> _onUpdatePanoramaBackgroundType(
    UpdatePanoramaBackgroundTypeEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = currentState.settings.copyWith(
      backgroundType: event.backgroundType,
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

  /// Updates the seam-nudge offset. Marks `seamOffsetIsManual` so Step 5's
  /// automatic seam-placement re-optimization stops overriding a deliberate
  /// adjustment.
  Future<void> _onUpdatePanoramaSeamOffset(
    UpdatePanoramaSeamOffsetEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = currentState.settings.copyWith(
      seamOffset: event.seamOffset,
      seamOffsetIsManual: true,
    );
    emit(currentState.copyWith(settings: updatedSettings));
  }

  /// Clears a manual seam-nudge and lets [_withAutoSeamOffset] pick again —
  /// forcing `seamOffsetIsManual: false` first so the no-op guard doesn't
  /// short-circuit the recomputation.
  Future<void> _onResetPanoramaSeamOffset(
    ResetPanoramaSeamOffsetEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final resetSettings = _withAutoSeamOffset(
      currentState.settings.copyWith(seamOffsetIsManual: false),
      energyProfile: currentState.energyProfile,
      sourceAspect: currentState.sourceAspect,
    );
    emit(currentState.copyWith(settings: resetSettings));
  }

  /// Resets zoom back to the default and persists it, mirroring
  /// `_onUpdatePanoramaScale`.
  Future<void> _onResetPanoramaScale(
    ResetPanoramaScaleEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = currentState.settings.copyWith(
      scale: PanoramaSettings.defaultScale,
    );
    emit(currentState.copyWith(settings: updatedSettings));

    final prefs = await _preferencesService.loadPreferences();
    await _preferencesService.savePreferences(
      prefs.copyWith(lastUsedScale: PanoramaSettings.defaultScale),
    );
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
  /// `emit(error) -> delay -> emit(previous)` cycling — that's the
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
