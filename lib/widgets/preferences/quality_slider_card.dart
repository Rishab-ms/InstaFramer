import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/preferences_bloc/preferences_bloc.dart';
import '../../blocs/preferences_bloc/preferences_event.dart';
import '../../theme/app_theme.dart';
import 'settings_card.dart';

/// Image quality slider card for adjusting JPEG export quality.
/// 
/// Allows users to select quality from 1-100% with:
/// - Live percentage display
/// - Visual slider with 99 discrete steps
/// - Helpful guidance text
/// - Haptic feedback on completion
class QualitySliderCard extends StatelessWidget {
  /// The current quality value (1-100)
  final int currentQuality;

  const QualitySliderCard({
    super.key,
    required this.currentQuality,
  });

  void _onQualityChanged(BuildContext context, int quality) {
    context.read<PreferencesBloc>().add(UpdateImageQualityEvent(quality));
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and current value
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'JPEG Quality',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '$currentQuality%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingSmall),
            
            // Guidance text
            Text(
              'Higher quality = larger file size. Recommended: 85%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            
            // Slider
            Slider(
              value: currentQuality.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              label: '$currentQuality%',
              onChanged: (value) => _onQualityChanged(context, value.toInt()),
              onChangeEnd: (_) => HapticFeedback.mediumImpact(),
            ),
            
            // Min/Max labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Smaller',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Larger',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}




