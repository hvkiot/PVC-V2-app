part of '../parameter_widgets.dart';

/// Discrete-value dropdown card — same header/unit-chip chrome as
/// [NumericStepperCard], but for a parameter whose device-accepted values
/// are a fixed, non-contiguous set rather than a free 1-unit-step range.
///
/// No free-text entry and no +/-  stepper: the only way to change the value
/// is picking one of [options]. Used by parameter 13 (Dither Frequency).
class DropdownValueCard extends StatelessWidget {
  final String title;
  final String command;
  final int value;
  final List<int> options;
  final String unit;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const DropdownValueCard({
    super.key,
    required this.title,
    required this.command,
    required this.value,
    required this.options,
    required this.onChanged,
    this.unit = '',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Defensive only: DropdownButton requires its value to match one of its
    // items exactly, or it throws. Under normal operation the current value
    // always comes from the same PAM-readback discrete set as `options`, so
    // this never triggers — it just avoids a hard crash if it ever doesn't,
    // without snapping/rounding it to anything (mirrors the existing
    // `_PWMField` dropdown pattern used for parameter 14).
    final dropdownValue = options.contains(value) ? value : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$title  $command',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (unit.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      unit,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: enabled
                    ? theme.colorScheme.surface
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: enabled
                      ? theme.colorScheme.primary
                      : theme.disabledColor.withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isDense: true,
                  isExpanded: true,
                  value: dropdownValue,
                  hint: Text(value.toString()),
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: enabled
                        ? theme.colorScheme.onSurface
                        : theme.disabledColor,
                  ),
                  items: [
                    for (final v in options)
                      DropdownMenuItem<int>(
                        value: v,
                        child: Text(v.toString()),
                      ),
                  ],
                  onChanged: enabled
                      ? (v) {
                          if (v != null) onChanged(v);
                        }
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
