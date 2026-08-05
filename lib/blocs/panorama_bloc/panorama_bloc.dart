import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/panorama_settings.dart';
import '../../models/panorama_spec.dart';
import '../../services/export_service.dart';
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
  // Unused for now — export wiring (`ExportPanoramaEvent` /
  // `_onExportPanorama`) lands in Step 3 and will call
  // `_exportService.exportPanorama(...)`. Kept as a constructor param already
  // so Step 3 doesn't have to change main.dart's provider wiring again.
  // ignore: unused_field
  final ExportService _exportService;
  final PreferencesService _preferencesService;

  PanoramaBloc({
    required ExportService exportService,
    required PreferencesService preferencesService,
  }) : _exportService = exportService,
       _preferencesService = preferencesService,
       super(const PanoramaInitialState()) {
    on<PanoramaSourceSelectedEvent>(_onPanoramaSourceSelected);
    on<UpdateTileCountEvent>(_onUpdateTileCount);
    on<UpdateFitModeEvent>(_onUpdateFitMode);
    on<UpdatePanoramaScaleEvent>(_onUpdatePanoramaScale);
    on<UpdatePanoramaBackgroundTypeEvent>(_onUpdatePanoramaBackgroundType);
    on<UpdatePanoramaBlurIntensityEvent>(_onUpdatePanoramaBlurIntensity);
    on<UpdatePanoramaSeamOffsetEvent>(_onUpdatePanoramaSeamOffset);
    on<ClearPanoramaEvent>(_onClearPanorama);
    // ExportPanoramaEvent / DismissPanoramaErrorEvent are wired in Step 3,
    // once PanoramaExportingState/PanoramaExportedState/PanoramaErrorState exist.
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

    emit(
      PanoramaReadyState(
        source: source,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        maxTiles: eligibility.maxTiles,
        settings: PanoramaSettings(
          tileCount: eligibility.suggestedTiles,
          scale: prefs.lastUsedScale,
          blurIntensity: prefs.lastUsedBlurIntensity,
        ),
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
    final updatedSettings = currentState.settings.copyWith(
      tileCount: event.tileCount,
    );
    emit(currentState.copyWith(settings: updatedSettings));
  }

  Future<void> _onUpdateFitMode(
    UpdateFitModeEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    if (state is! PanoramaReadyState) return;
    final currentState = state as PanoramaReadyState;
    final updatedSettings = currentState.settings.copyWith(
      fitMode: event.fitMode,
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

  Future<void> _onClearPanorama(
    ClearPanoramaEvent event,
    Emitter<PanoramaState> emit,
  ) async {
    emit(const PanoramaInitialState());
  }
}
