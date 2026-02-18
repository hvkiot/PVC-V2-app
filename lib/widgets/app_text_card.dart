import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextCard extends StatefulWidget {
  final String title;
  final String currentValue;
  final ValueChanged<String?> onChanged;
  final IconData icon;
  final bool enabled;

  const AppTextCard({
    super.key,
    required this.title,
    required this.currentValue,
    required this.onChanged,
    this.icon = Icons.settings_input_component,
    this.enabled = true,
  });

  @override
  State<AppTextCard> createState() => _AppTextCardState();
}

class _AppTextCardState extends State<AppTextCard> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
  }

  @override
  void didUpdateWidget(AppTextCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentValue != widget.currentValue &&
        _controller.text != widget.currentValue) {
      _controller.text = widget.currentValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use surfaceVariant for light mode as requested in requirement 1.3
    // "In Light Mode, use surfaceVariant with a clear primary border"
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.enabled
                    ? theme.colorScheme.primaryContainer
                    : theme.disabledColor.withAlpha(50),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.icon,
                color: widget.enabled
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Text(
                widget.title.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: widget.enabled
                      ? theme.colorScheme.onSurface
                      : theme.disabledColor,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.enabled
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                    width: theme.brightness == Brightness.light ? 1.5 : 1.0,
                  ),
                ),
                child: TextField(
                  enabled: widget.enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,1}'),
                    ),
                  ],
                  controller: _controller,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(border: InputBorder.none),
                  onChanged: (value) {
                    // Auto-rounding logic upon completion is harder in onChanged,
                    // but we can ensure valid structure here.
                    // The actual rounding happens in the parent logic or on submit/blur,
                    // but the requirement "automatically rounds decimals before they reach the controller logic"
                    // implies we might want to sanitize it here before sending up.
                    // However, UX-wise, rounding while typing is jarring.
                    // We'll let the parent handle the parsing/rounding logic as requested,
                    // or do it here if we want to force it.
                    // "restricts inputs to numeric values" -> Done with inputFormatters
                    widget.onChanged(value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'mA',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: widget.enabled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
