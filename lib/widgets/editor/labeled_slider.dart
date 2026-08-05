import 'package:flutter/material.dart';

/// Icon-flanked slider with a bold value label, used for scale/blur/seam-nudge
/// controls. Callers own the outer container (background, padding) since that
/// differs between call sites.
class LabeledSlider extends StatelessWidget {
  final IconData leadingIcon;
  final IconData trailingIcon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const LabeledSlider({
    super.key,
    required this.leadingIcon,
    required this.trailingIcon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(leadingIcon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            year2023: false,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        Icon(trailingIcon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            valueLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
