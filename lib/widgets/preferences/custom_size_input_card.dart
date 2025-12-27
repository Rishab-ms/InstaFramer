import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/preferences_bloc/preferences_bloc.dart';
import '../../blocs/preferences_bloc/preferences_event.dart';
import '../../models/image_size.dart';
import '../../theme/app_theme.dart';
import 'settings_card.dart';

/// Custom image size input card for width and height entry.
/// 
/// Provides two text fields for entering custom dimensions:
/// - Width input (digits only)
/// - Height input (digits only)
/// - Real-time validation and BLoC updates
/// - Helpful guidance text
class CustomSizeInputCard extends StatelessWidget {
  /// Controller for width input
  final TextEditingController widthController;
  
  /// Controller for height input
  final TextEditingController heightController;

  const CustomSizeInputCard({
    super.key,
    required this.widthController,
    required this.heightController,
  });

  void _onDimensionChanged(BuildContext context) {
    final width = int.tryParse(widthController.text);
    final height = int.tryParse(heightController.text);
    
    if (width != null && width > 0 && height != null && height > 0) {
      context.read<PreferencesBloc>().add(
        UpdateCustomImageSizeEvent(
          ImageSize(width: width, height: height),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMedium,
        AppTheme.spacingMedium,
        AppTheme.spacingMedium,
        0,
      ),
      child: SettingsCard(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Custom Dimensions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingMedium),
              
              // Width and Height inputs
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widthController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Width',
                        suffixText: 'px',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _onDimensionChanged(context),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMedium),
                  const Icon(Icons.close, size: 16),
                  const SizedBox(width: AppTheme.spacingMedium),
                  Expanded(
                    child: TextField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        suffixText: 'px',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _onDimensionChanged(context),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacingSmall),
              
              // Guidance text
              Text(
                'Recommended: 1080-4000px for optimal Instagram quality',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




