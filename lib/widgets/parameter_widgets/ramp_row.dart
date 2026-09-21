part of '../parameter_widgets.dart';

/// Ramp row with label, editable numeric field, and quick-set buttons.
class RampRow extends StatefulWidget {
  final String label;
  final String command;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const RampRow({
    super.key,
    required this.label,
    required this.command,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<RampRow> createState() => _RampRowState();
}

class _RampRowState extends State<RampRow> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant RampRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      _ctrl.text = widget.value.toString();
    }
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    final parsed = int.tryParse(_ctrl.text.trim());
    if (parsed == null) {
      _ctrl.text = widget.value.toString();
      return;
    }
    final clamped = parsed.clamp(1, 120000);
    if (clamped != widget.value) widget.onChanged(clamped);
    if (clamped.toString() != _ctrl.text) _ctrl.text = clamped.toString();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.command,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _StepperButton(
                  icon: Icons.remove,
                  onPressed: widget.enabled && widget.value > 1
                      ? () => widget.onChanged(
                          (widget.value - 10).clamp(1, 120000),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.enabled
                            ? theme.colorScheme.onSurface
                            : theme.disabledColor,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: widget.enabled
                            ? theme.colorScheme.surface
                            : theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 14,
                        ),
                        suffixText: 'ms',
                        suffixStyle: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _commit(),
                      onTapOutside: (_) => _focus.unfocus(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StepperButton(
                  icon: Icons.add,
                  onPressed: widget.enabled && widget.value < 120000
                      ? () => widget.onChanged(
                          (widget.value + 10).clamp(1, 120000),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                _QuickButton(
                  label: '+50',
                  onTap: widget.enabled
                      ? () => widget.onChanged(
                          (widget.value + 50).clamp(1, 120000),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                _QuickButton(
                  label: '+500',
                  onTap: widget.enabled
                      ? () => widget.onChanged(
                          (widget.value + 500).clamp(1, 120000),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                _QuickButton(
                  label: '+1k',
                  onTap: widget.enabled
                      ? () => widget.onChanged(
                          (widget.value + 1000).clamp(1, 120000),
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
