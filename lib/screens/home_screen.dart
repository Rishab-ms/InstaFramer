import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../blocs/panorama_bloc/panorama_bloc.dart';
import '../blocs/panorama_bloc/panorama_event.dart';
import '../blocs/panorama_bloc/panorama_state.dart';
import '../blocs/photo_bloc/photo_bloc.dart';
import '../blocs/photo_bloc/photo_state.dart';
import '../theme/app_theme.dart';
import '../widgets/home/create_mode_dialog.dart';
import '../widgets/home/framer_logo_icon.dart';
import 'editor_screen.dart';
import 'panorama_editor_screen.dart';
import 'photo_picker_screen.dart';
import 'preferences_screen.dart';

/// Home screen of InstaFramer - the landing page of the app.
///
/// Displays:
/// - App branding and description
/// - Feature highlights (aspect ratios, backgrounds, scaling)
/// - "Select Photos" button to launch the gallery picker
/// - Settings button in app bar
///
/// Automatically navigates to [EditorScreen] when photos are selected.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PreferencesScreen(),
                ),
              );
            },
          ),
        ],
      ),
      // Home listens to two independent blocs (PhotoBloc for the framer,
      // PanoramaBloc for the carousel flow), so a single BlocConsumer can't
      // cover both. MultiBlocListener composes the PanoramaBloc listener
      // alongside the existing PhotoBloc BlocConsumer without nesting one
      // builder inside another's listener. Only PhotoBloc drives this
      // screen's *builder* (the panorama flow has no Home-visible UI state,
      // just a one-shot navigate-or-snackbar reaction to source selection),
      // so PanoramaBloc only needs a listener, not a consumer.
      body: MultiBlocListener(
        listeners: [
          BlocListener<PanoramaBloc, PanoramaState>(
            // Mirrors PhotoBloc's listenWhen pattern below: react only on
            // the transition INTO Ready (not on every rebuild while already
            // ready), plus unconditionally on Ineligible since that's always
            // a fresh pick attempt to react to.
            listenWhen: (previous, current) =>
                (previous is! PanoramaReadyState &&
                    current is PanoramaReadyState) ||
                current is PanoramaIneligibleState,
            listener: (context, state) {
              if (state is PanoramaReadyState) {
                // Push only here, per Flow A in the panorama plan. Pushing
                // PanoramaEditorScreen for an ineligible source would land
                // the user on a screen whose only content is "no".
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PanoramaEditorScreen(),
                  ),
                );
              } else if (state is PanoramaIneligibleState) {
                // Stay on Home; the picker is one tap away via the same
                // button rather than forcing a back-navigation.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.reason),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
        child: BlocConsumer<PhotoBloc, PhotoState>(
          listenWhen: (previous, current) {
            // Only navigate when transitioning TO PhotosLoadedState from a non-loaded state
            // This prevents navigation during ongoing editor operations
            //from external share context:
            // If app starts cold via share: previous is InitialState, current is LoadedState -> Returns TRUE
            // If app is running: previous is LoadingState (from picker), current is LoadedState -> Returns TRUE
            return (previous is! PhotosLoadedState &&
                    current is PhotosLoadedState) ||
                current is PhotoErrorState;
          },
          listener: (context, state) {
            // A warm share while an editor is already open re-emits
            // PhotosLoadedState on this (backgrounded) Home route too,
            // without this guard, Home would push a second EditorScreen on
            // top of the one already showing the merged photos.
            if (ModalRoute.of(context)?.isCurrent != true) return;
            // Navigate to editor when photos are successfully loaded (first time only)
            if (state is PhotosLoadedState) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditorScreen()),
              );
            } else if (state is PhotoErrorState) {
              // Show error message as a snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'OK',
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            // Shows CreateModeDialog for a fresh, panorama-eligible single
            // photo share (SharedPhotoModeSelectionState). Deliberately
            // here rather than in `listener`: `listener` only fires on the
            // transition *into* this state, but that transition may have
            // happened while Home wasn't the current route (an editor was
            // open), in which case the isCurrent guard above suppresses it
            //. Home is then left silently parked in this state with no
            // dialog ever shown ("dangling state", see the panorama plan's
            // Flow B). `builder` runs both at the original transition (if
            // Home was already current) and again later when Home becomes
            // current. Calling `ModalRoute.of(context)` here subscribes
            // this build to route current-ness changes, so popping back to
            // Home from the editor re-triggers this check. The `isCurrent`
            // condition itself makes this idempotent: once shown, the
            // dialog's own route makes Home non-current again, so the
            // check no longer matches until the state changes.
            if (state is SharedPhotoModeSelectionState &&
                ModalRoute.of(context)?.isCurrent == true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  CreateModeDialog.show(context, state.photo);
                }
              });
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppTheme.spacingLarge),

                    // App Logo/Icon. Sized down from a full-screen hero to
                    // something a returning user's eye can skip past quickly
                    // on the way to the buttons below.
                    Center(
                      child: FramerLogoIcon(
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),

                    // App Title
                    Text(
                      'InstaFramer',
                      style: AppTheme.headlineLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingXSmall),

                    // App Description
                    Text(
                      'Frame your photos perfectly for Instagram',
                      style: AppTheme.bodyLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingLarge),

                    // Feature strip, one compact row instead of three full
                    // icon+title+description rows, so returning users scan
                    // past it in a glance rather than reading three lines of
                    // onboarding copy on every open.
                    const Row(
                      children: [
                        Expanded(
                          child: _FeatureChip(
                            icon: LucideIcons.ratio,
                            label: 'Aspect ratios',
                          ),
                        ),
                        Expanded(
                          child: _FeatureChip(
                            icon: LucideIcons.palette,
                            label: 'Backgrounds',
                          ),
                        ),
                        Expanded(
                          child: _FeatureChip(
                            icon: LucideIcons.galleryHorizontalEnd,
                            label: 'Panoramas',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingXLarge),

                    // Select Photos Button. The primary action; this is the
                    // main framing workflow, so it carries all the visual
                    // weight (filled, full-size).
                    if (state is PhotosLoadingState)
                      const Center(child: CircularProgressIndicator())
                    else
                      FilledButton.icon(
                        onPressed: () {
                          PhotoPickerScreen.pickPhotos(context);
                        },
                        icon: const Icon(LucideIcons.images, size: 24),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            'Select Photos',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            AppTheme.minTouchTarget + 8,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppTheme.spacingLarge),

                    // Panorama Carousel entry point. Splits one wide photo
                    // into N tiles of 4:5 for an Instagram carousel. Kept as
                    // a plain text button rather than a second full-size
                    // outlined button: it's a secondary, single-purpose mode
                    // rather than a peer choice to "Select Photos", so it
                    // shouldn't carry the same visual weight.
                    Center(
                      child: TextButton.icon(
                        onPressed: () async {
                          // pickSinglePhoto (unlike pickPhotos) returns the
                          // asset directly rather than dispatching to a bloc
                          // itself. This callsite decides where it goes,
                          // which is what lets one picker method serve both
                          // the framer (PhotoBloc) and panorama (PanoramaBloc)
                          // entry points.
                          final asset = await PhotoPickerScreen.pickSinglePhoto(
                            context,
                          );
                          // context.mounted check is required: pickSinglePhoto
                          // awaits the picker route, so Home may have been
                          // popped in the meantime (e.g. user backgrounds the
                          // app and it gets torn down) by the time it resolves.
                          if (asset == null || !context.mounted) return;
                          context.read<PanoramaBloc>().add(
                            PanoramaSourceSelectedEvent(asset),
                          );
                          // Navigation is NOT here. The listener above pushes
                          // only on PanoramaReadyState, so an ineligible photo
                          // shows a snackbar instead of a dead-end screen.
                        },
                        icon: const Icon(
                          LucideIcons.galleryHorizontalEnd,
                          size: 20,
                        ),
                        label: const Text('Create a Panorama Carousel'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compact icon-over-label chip for the home screen's feature strip. A
/// glanceable one-line reminder of what the app does, not an onboarding
/// explanation (that's what the description used to spell out per-feature).
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
