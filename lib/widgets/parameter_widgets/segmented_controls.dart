part of '../parameter_widgets.dart';

/// Segmented control — ON / OFF / AUTO or + / - options.
///
/// Matches the HTML `.seg` pattern. Wraps in a Card.
class SegmentedCard extends StatelessWidget {
  final String title;
  final String command;
  final List<String> options;
  final String currentValue;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? helpText;

  const SegmentedCard({
    super.key,
    required this.title,
    required this.command,
    required this.options,
    required this.currentValue,
    required this.onChanged,
    this.enabled = true,
    this.helpText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title  $command',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _SegmentedControl(
              options: options,
              selected: currentValue,
              onChanged: enabled ? onChanged : null,
            ),
            if (helpText != null) ...[
              const SizedBox(height: 8),
              Text(
                helpText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String>? onChanged;

  const _SegmentedControl({
    required this.options,
    required this.selected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final enabled = onChanged != null;

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.grey.shade200
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options.map((option) {
          final isSelected = option == selected;
          return Expanded(
            child: GestureDetector(
              onTap: enabled ? () => onChanged!(option) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withAlpha(60),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  option,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : (enabled
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.disabledColor),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Polarity card — shows +/- segmented for a channel.
///
/// Used by parameter 06 (POL).
class PolarityCard extends StatelessWidget {
  final String label;
  final String command;
  final String currentValue;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const PolarityCard({
    super.key,
    this.label = '',
    required this.command,
    required this.currentValue,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label  $command',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _SegmentedControl(
              options: const ['+', '-'],
              selected: currentValue,
              onChanged: enabled ? onChanged : null,
            ),
            const SizedBox(height: 8),
            Text(
              'Output direction for this channel.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
