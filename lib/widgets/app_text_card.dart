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
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  @override
  void didUpdateWidget(AppTextCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Focus Preservation: Only accept incoming value updates
    // when the keyboard is NOT active. This prevents the hardware
    // live-feed from "stealing" text while the user is typing.
    if (!_hasFocus &&
        oldWidget.currentValue != widget.currentValue &&
        _controller.text != widget.currentValue) {
      _controller.text = widget.currentValue;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

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
                  focusNode: _focusNode,
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
