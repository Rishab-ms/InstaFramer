import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/panorama_bloc/panorama_bloc.dart';
import '../blocs/panorama_bloc/panorama_event.dart';
import '../blocs/panorama_bloc/panorama_state.dart';
import '../blocs/photo_bloc/photo_bloc.dart';
import '../blocs/photo_bloc/photo_state.dart';
import '../theme/app_theme.dart';
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
            icon: const Icon(Icons.settings_outlined),
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
      // cover both — MultiBlocListener composes the PanoramaBloc listener
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
                // Push only here, per Flow A in the panorama plan — pushing
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
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // App Logo/Icon
                    Icon(
                      Icons.photo_size_select_large_rounded,
                      size: 120,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppTheme.spacingLarge),

                    // App Title
                    Text(
                      'InstaFramer',
                      style: AppTheme.headlineLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),

                    // App Description
                    Text(
                      'Frame your photos perfectly for Instagram',
                      style: AppTheme.bodyLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingXLarge),

                    // Features List
                    _FeatureItem(
                      icon: Icons.aspect_ratio,
                      title: 'Custom Aspect Ratios',
                      description: 'Perfect 4:5 portrait or 1:1 square frames',
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                    _FeatureItem(
                      icon: Icons.palette_outlined,
                      title: 'Beautiful Backgrounds',
                      description: 'White, black, or extended blur effects',
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                    _FeatureItem(
                      icon: Icons.panorama_horizontal_outlined,
                      title: 'Panorama Carousels',
                      description:
                          'Split wide photos into an Instagram carousel',
                    ),
                    const SizedBox(height: AppTheme.spacingXLarge),

                    // Select Photos Button
                    if (state is PhotosLoadingState)
                      const Center(child: CircularProgressIndicator())
                    else
                      FilledButton.icon(
                        onPressed: () {
                          PhotoPickerScreen.pickPhotos(context);
                        },
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 24,
                        ),
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
                    const SizedBox(height: AppTheme.spacingMedium),

                    // Panorama Carousel entry point — splits one wide photo
                    // into N tiles of 4:5 for an Instagram carousel.
                    OutlinedButton.icon(
                      onPressed: () async {
                        // pickSinglePhoto (unlike pickPhotos) returns the
                        // asset directly rather than dispatching to a bloc
                        // itself — this callsite decides where it goes,
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
                        // Navigation is NOT here — the listener above pushes
                        // only on PanoramaReadyState, so an ineligible photo
                        // shows a snackbar instead of a dead-end screen.
                      },
                      icon: const Icon(
                        Icons.panorama_horizontal_outlined,
                        size: 24,
                      ),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          'Panorama Carousel',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppTheme.minTouchTarget + 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),

                    // Info Text
                    Text(
                      'Select up to 30 photos from your gallery',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
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

/// Feature item widget displaying an icon, title, and description.
///
/// Used to highlight key features on the home screen.
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingSmall),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 24,
          ),
        ),
        const SizedBox(width: AppTheme.spacingMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.titleLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTheme.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
