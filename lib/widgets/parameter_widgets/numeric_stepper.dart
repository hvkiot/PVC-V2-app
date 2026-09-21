part of '../parameter_widgets.dart';

/// Numeric field with stepper buttons, editable text field, and unit label.
///
/// Mirrors the HTML `num()` builder.  [value] is the raw integer written to
/// the controller (no percent math in the UI). Field is height 52 and fully
/// writable — tap to type, stepper to adjust, auto-clamped on submit.
class NumericStepperCard extends StatefulWidget {
  final String title;
  final String command;
  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final String? warningText;
  final int? warningThreshold;

  const NumericStepperCard({
    super.key,
    required this.title,
    required this.command,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 50,
    this.unit = '',
    this.enabled = true,
    this.warningText,
    this.warningThreshold,
  });

  @override
  State<NumericStepperCard> createState() => _NumericStepperCardState();
}

class _NumericStepperCardState extends State<NumericStepperCard> {
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
  void didUpdateWidget(covariant NumericStepperCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus) {
      _ctrl.text = widget.value.toString();
    }
    if (oldWidget.enabled != widget.enabled && !widget.enabled) {
      _focus.unfocus();
    }
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    final raw = _ctrl.text.trim().replaceAll(',', '.');
    final parsed = int.tryParse(raw.split('.').first);
    if (parsed == null) {
      _ctrl.text = widget.value.toString();
      return;
    }
    final clamped = parsed.clamp(widget.min, widget.max);
    if (clamped != widget.value) {
      widget.onChanged(clamped);
    } else if (clamped.toString() != _ctrl.text) {
      _ctrl.text = clamped.toString();
    }
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
    final showWarning =
        widget.warningThreshold != null &&
        widget.value > widget.warningThreshold!;

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
                    '${widget.title}  ${widget.command}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.unit.isNotEmpty)
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
                      widget.unit,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
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
                  onPressed: widget.enabled && widget.value > widget.min
                      ? () => widget.onChanged(
                          (widget.value - widget.step).clamp(
                            widget.min,
                            widget.max,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: false,
                        decimal: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                      ],
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
                          horizontal: 12,
                          vertical: 14,
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
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: theme.disabledColor.withAlpha(80),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _commit(),
                      onTapOutside: (_) => _focus.unfocus(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StepperButton(
                  icon: Icons.add,
                  onPressed: widget.enabled && widget.value < widget.max
                      ? () => widget.onChanged(
                          (widget.value + widget.step).clamp(
                            widget.min,
                            widget.max,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            if (showWarning && widget.warningText != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.warningText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
