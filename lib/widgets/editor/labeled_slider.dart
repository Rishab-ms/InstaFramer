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
  final ValueChanged<double>? onChangeEnd;

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
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(leadingIcon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          // The default M3 track only shows gaps/tick marks once each
          // division is wide enough — with the division counts these
          // sliders use, that default reads as one continuous track. A
          // slightly smaller tick radius lowers that width threshold so the
          // discrete stops are reliably visible instead of "clean".
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              tickMarkShape: const RoundSliderTickMarkShape(
                tickMarkRadius: 1.5,
              ),
              activeTickMarkColor: theme.colorScheme.onPrimary.withValues(
                alpha: 0.8,
              ),
              inactiveTickMarkColor: theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.6),
              trackGap: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              year2023: false,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
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
