import 'package:flutter/material.dart';

class AppTextCard extends StatefulWidget {
  final String title;
  final String currentValue;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  const AppTextCard({
    super.key,
    required this.title,
    required this.currentValue,
    required this.onChanged,
    this.icon = Icons.settings_input_component,
  });

  @override
  State<AppTextCard> createState() => _AppTextCardState();
}

class _AppTextCardState extends State<AppTextCard> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Initialize once with the initial value
    _controller = TextEditingController(text: widget.currentValue);
  }

  @override
  void didUpdateWidget(AppTextCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the hardware value changes from the kit, update the text
    // but only if the user isn't currently typing
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.icon,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Text(
                widget.title.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  keyboardType: TextInputType.number,
                  controller: _controller, // Use the stable controller
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(border: InputBorder.none),
                  onChanged: widget.onChanged,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'mA',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
