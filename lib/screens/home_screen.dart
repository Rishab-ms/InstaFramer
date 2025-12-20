import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/photo_bloc/photo_bloc.dart';
import '../blocs/photo_bloc/photo_state.dart';
import '../theme/app_theme.dart';
import 'editor_screen.dart';
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
        title: const Text('InstaFramer'),
        centerTitle: true,
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
      body: BlocConsumer<PhotoBloc, PhotoState>(
        listenWhen: (previous, current) {
          // Only navigate when transitioning TO PhotosLoadedState from a non-loaded state
          // This prevents navigation during ongoing editor operations
          return (previous is! PhotosLoadedState && current is PhotosLoadedState) ||
                 current is PhotoErrorState;
        },
        listener: (context, state) {
          // Navigate to editor when photos are successfully loaded (first time only)
          if (state is PhotosLoadedState) {
            debugPrint("navigating to editor screen (initial photo selection)");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditorScreen(),
              ),
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
                    icon: Icons.tune,
                    title: 'Fine-tune Scaling',
                    description: 'Control exactly how your photo fits',
                  ),
                  const SizedBox(height: AppTheme.spacingXLarge),
                  
                  // Select Photos Button
                  if (state is PhotosLoadingState)
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () {
                        PhotoPickerScreen.pickPhotos(context);
                      },
                      icon: const Icon(Icons.photo_library_outlined, size: 24),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          'Select Photos',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(AppTheme.minTouchTarget + 8),
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

