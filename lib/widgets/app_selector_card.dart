import 'package:flutter/material.dart';

class AppSelectorCard extends StatelessWidget {
  final String title;
  final String currentValue;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final IconData icon;
  final bool enabled;

  const AppSelectorCard({
    super.key,
    required this.title,
    required this.currentValue,
    required this.options,
    required this.onChanged,
    this.icon = Icons.settings_input_component,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.brightness == Brightness.light
        ? theme.colorScheme.surfaceContainer
        : theme.cardTheme.color;

    return Card(
      color: surfaceColor,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 1. Icon with subtle background
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: enabled
                    ? theme.colorScheme.primaryContainer
                    : theme.disabledColor.withAlpha(50),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: enabled
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),

            // 2. Title Section
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: enabled
                      ? theme.colorScheme.onSurface
                      : theme.disabledColor,
                ),
              ),
            ),

            // 3. Custom Themed Dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                    width: theme.brightness == Brightness.light ? 1.5 : 1.0,
                  ),
                ),
                child: IgnorePointer(
                  ignoring: !enabled,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: options.contains(currentValue)
                          ? currentValue
                          : options.first,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: enabled
                            ? theme.colorScheme.primary
                            : theme.disabledColor,
                      ),
                      style: TextStyle(
                        color: enabled
                            ? theme.colorScheme.primary
                            : theme.disabledColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                      items: options.map((String val) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(val),
                        );
                      }).toList(),
                      onChanged: onChanged,
                      dropdownColor: theme.cardTheme.color,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
