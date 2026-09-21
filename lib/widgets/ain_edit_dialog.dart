import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AinEditResult {
  final int a;
  final int b;
  final int c;
  final String x;

  const AinEditResult({
    required this.a,
    required this.b,
    required this.c,
    required this.x,
  });
}

class AinEditDialog extends StatefulWidget {
  final int initialA;
  final int initialB;
  final int initialC;
  final String initialX;
  final String channelLabel;

  const AinEditDialog({
    super.key,
    required this.initialA,
    required this.initialB,
    required this.initialC,
    required this.initialX,
    this.channelLabel = 'A',
  });

  static Future<AinEditResult?> show(
    BuildContext context, {
    required int initialA,
    required int initialB,
    required int initialC,
    required String initialX,
    String channelLabel = 'A',
  }) {
    return showModalBottomSheet<AinEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AinEditDialog(
        initialA: initialA,
        initialB: initialB,
        initialC: initialC,
        initialX: initialX,
        channelLabel: channelLabel,
      ),
    );
  }

  @override
  State<AinEditDialog> createState() => _AinEditDialogState();
}

class _AinEditDialogState extends State<AinEditDialog> {
  late TextEditingController _ctrlA;
  late TextEditingController _ctrlB;
  late TextEditingController _ctrlC;
  String _selectedX = 'V';
  String _selectedPreset = 'User defined';

  static const _presetValues = {
    '0-10V': (a: 1000, b: 1000, c: 0, x: 'V'),
    '4-20mA': (a: 1250, b: 1000, c: 2000, x: 'C'),
  };

  @override
  void initState() {
    super.initState();
    _ctrlA = TextEditingController(text: widget.initialA.toString());
    _ctrlB = TextEditingController(text: widget.initialB.toString());
    _ctrlC = TextEditingController(text: widget.initialC.toString());
    // Normalize the incoming device/PAM representation to the app's
    // editable V/C representation at this UI boundary. Confirmed hardware
    // behavior: PAM readback does NOT echo the token the app writes — it
    // reports 'U' for voltage and 'I' for current (write V -> readback U;
    // write C -> readback I). This dropdown intentionally offers only V/C
    // — passing 'U'/'I' straight through would make DropdownButton assert
    // (no matching DropdownMenuItem). 'None'/empty/anything else falls
    // back to 'V' as a safe editable default.
    _selectedX = switch (widget.initialX) {
      'V' || 'U' => 'V',
      'C' || 'I' => 'C',
      _ => 'V',
    };
    _detectPreset();
  }

  @override
  void dispose() {
    _ctrlA.dispose();
    _ctrlB.dispose();
    _ctrlC.dispose();
    super.dispose();
  }

  void _detectPreset() {
    final a = int.tryParse(_ctrlA.text) ?? 0;
    final b = int.tryParse(_ctrlB.text) ?? 0;
    final c = int.tryParse(_ctrlC.text) ?? 0;
    for (final entry in _presetValues.entries) {
      final p = entry.value;
      if (a == p.a && b == p.b && c == p.c && _selectedX == p.x) {
        setState(() => _selectedPreset = entry.key);
        return;
      }
    }
    setState(() => _selectedPreset = 'User defined');
  }

  void _applyPreset(String? preset) {
    if (preset == null || preset == 'User defined') {
      setState(() => _selectedPreset = 'User defined');
      return;
    }
    final p = _presetValues[preset]!;
    setState(() {
      _selectedPreset = preset;
      _ctrlA.text = p.a.toString();
      _ctrlB.text = p.b.toString();
      _ctrlC.text = p.c.toString();
      _selectedX = p.x;
    });
  }

  void _onFieldChanged() => _detectPreset();

  void _save() {
    final a = int.tryParse(_ctrlA.text.trim()) ?? widget.initialA;
    final b = int.tryParse(_ctrlB.text.trim()) ?? widget.initialB;
    final c = int.tryParse(_ctrlC.text.trim()) ?? widget.initialC;
    Navigator.of(context).pop(
      AinEditResult(
        a: a.clamp(-10000, 10000),
        b: b.clamp(-10000, 10000),
        c: c.clamp(-10000, 10000),
        x: _selectedX,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.tune, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Edit AIN parameters',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Two-column layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 500;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildParameters(theme)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildPresets(theme)),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildParameters(theme),
                            const SizedBox(height: 16),
                            _buildPresets(theme),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Formula
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withAlpha(
                            60,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.primary.withAlpha(40),
                          ),
                        ),
                        child: Text(
                          'output = (A / B) \u00D7 (input \u2212 C)',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Comment
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withAlpha(80),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comment',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Input scaling via linear equation',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('OK'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameters(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Parameters',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildInputRow(
          theme,
          label: 'A',
          controller: _ctrlA,
          suffix: 'A/B',
          help: 'Numerator (default 1000)',
        ),
        const SizedBox(height: 10),
        _buildInputRow(
          theme,
          label: 'B',
          controller: _ctrlB,
          suffix: 'A/B',
          help: 'Denominator (default 1000)',
        ),
        const SizedBox(height: 10),
        _buildInputRow(
          theme,
          label: 'C',
          controller: _ctrlC,
          suffix: '0.01%',
          help: 'Input offset (default 0)',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'X',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outline.withAlpha(100),
                  width: 1.2,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isDense: true,
                  value: _selectedX,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'V', child: Text('V  (voltage)')),
                    DropdownMenuItem(value: 'C', child: Text('C  (current)')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedX = v);
                      _onFieldChanged();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputRow(
    ThemeData theme, {
    required String label,
    required TextEditingController controller,
    required String suffix,
    required String help,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
            ],
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              suffixText: suffix,
              suffixStyle: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            onChanged: (_) => _onFieldChanged(),
          ),
        ),
      ],
    );
  }

  Widget _buildPresets(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withAlpha(80)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Presets',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildRadioTile(
            theme,
            value: 'User defined',
            groupValue: _selectedPreset,
            onChanged: _applyPreset,
          ),
          _buildRadioTile(
            theme,
            value: '0-10V',
            groupValue: _selectedPreset,
            onChanged: _applyPreset,
            subtitle: 'A=1000, B=1000, C=0, X=V',
          ),
          _buildRadioTile(
            theme,
            value: '4-20mA',
            groupValue: _selectedPreset,
            onChanged: _applyPreset,
            subtitle: 'A=1250, B=1000, C=2000, X=C',
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile(
    ThemeData theme, {
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
    String? subtitle,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: RadioGroup<String>(
          onChanged: onChanged,
          groupValue: groupValue,
          child: Row(
            children: [
              Radio<String>(
                value: value,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
