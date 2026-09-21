part of '../parameter_widgets.dart';

class CurrentLoopGainRow extends StatefulWidget {
  final String label;
  final String command;
  final int value;
  final int min;
  final int max;
  final List<int> steps;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const CurrentLoopGainRow({
    super.key,
    required this.label,
    required this.command,
    required this.value,
    required this.min,
    required this.max,
    required this.steps,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<CurrentLoopGainRow> createState() => _CurrentLoopGainRowState();
}

class _CurrentLoopGainRowState extends State<CurrentLoopGainRow> {
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
  void didUpdateWidget(covariant CurrentLoopGainRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      _ctrl.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
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
    final clamped = parsed.clamp(widget.min, widget.max);
    _ctrl.text = clamped.toString();
    if (clamped != widget.value) widget.onChanged(clamped);
  }

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
              widget.label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _SmallButton(
                  label: '\u2212',
                  onTap: widget.enabled
                      ? () {
                          final v = (widget.value - 1).clamp(
                            widget.min,
                            widget.max,
                          );
                          widget.onChanged(v);
                        }
                      : null,
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 48,
                  width: 140,
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
                        vertical: 12,
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
                const SizedBox(width: 6),
                _SmallButton(
                  label: '+',
                  onTap: widget.enabled
                      ? () {
                          final v = (widget.value + 1).clamp(
                            widget.min,
                            widget.max,
                          );
                          widget.onChanged(v);
                        }
                      : null,
                ),
                const SizedBox(width: 6),

                for (final step in widget.steps) ...[
                  _QuickButton(
                    label: step >= 1000 ? '+${step ~/ 1000}k' : '+$step',
                    onTap: widget.enabled
                        ? () => widget.onChanged(
                            (widget.value + step).clamp(widget.min, widget.max),
                          )
                        : null,
                  ),
                  if (step != widget.steps.last) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SmallButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? theme.colorScheme.primaryContainer
          : theme.disabledColor.withAlpha(30),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: enabled
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
