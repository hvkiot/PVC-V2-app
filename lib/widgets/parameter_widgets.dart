import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Reusable parameter form widgets — match AppTextCard / AppSelectorCard theme
// ---------------------------------------------------------------------------

/// Parameter header with ID badge, name, and subtitle.
///
/// Mirrors the HTML `.phead` pattern from the design mockup. Intentionally
/// does NOT show a PAM MODE STD/EXP badge — PVC screens are Basic/Advanced,
/// and the underlying PAM MODE grouping stays an implementation detail (see
/// AGENTS.md "PVC PRODUCT DESIGN PRINCIPLE" / "USER-FACING TERMINOLOGY").
class ParamHeader extends StatelessWidget {
  final String id;
  final String name;
  final String? command;
  final String? subtitle;

  const ParamHeader({
    super.key,
    required this.id,
    required this.name,
    this.command,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ID badge
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            id,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Name + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

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

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepperButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: enabled
            ? theme.colorScheme.primaryContainer
            : theme.disabledColor.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? theme.colorScheme.primary : theme.disabledColor,
          ),
        ),
      ),
    );
  }
}

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

/// Tabbed panel with two tab children (e.g. AIN input type / advanced scaling).
class TabbedPanelCard extends StatelessWidget {
  final String title;
  final String command;
  final String? subtitle;
  final List<String> tabLabels;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final List<Widget> tabChildren;
  final bool enabled;

  const TabbedPanelCard({
    super.key,
    required this.title,
    required this.command,
    required this.tabLabels,
    required this.selectedTab,
    required this.onTabChanged,
    required this.tabChildren,
    this.subtitle,
    this.enabled = true,
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
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            // Tab bar
            Row(
              children: List.generate(tabLabels.length, (i) {
                final isSelected = i == selectedTab;
                return Expanded(
                  child: GestureDetector(
                    onTap: enabled ? () => onTabChanged(i) : null,
                    child: Container(
                      margin: EdgeInsets.only(
                        right: i < tabLabels.length - 1 ? 6 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withAlpha(60),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(11),
                        color: isSelected
                            ? theme.colorScheme.primary.withAlpha(15)
                            : Colors.transparent,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tabLabels[i],
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            // Tab content
            tabChildren[selectedTab],
          ],
        ),
      ),
    );
  }
}

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

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _QuickButton({required this.label, this.onTap});

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: enabled ? theme.colorScheme.primary : theme.disabledColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Safety interlock banner — shown when PIN 15 or PIN 6 is active.
class SafetyBanner extends StatelessWidget {
  final String pinLabel;
  final bool isActive;

  const SafetyBanner({
    super.key,
    required this.pinLabel,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Disable $pinLabel to modify settings',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Info / help card — matches the HTML `.helpcard` pattern.
class HelpCard extends StatelessWidget {
  final String title;
  final String message;

  const HelpCard({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: '$title ',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                children: [
                  TextSpan(
                    text: message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
