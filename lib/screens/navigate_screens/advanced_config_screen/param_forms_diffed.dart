part of '../advanced_config_screen.dart';

class _Param05Limit extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  final String mode;
  const _Param05Limit({
    required this.draft,
    required this.draftNotifier,
    required this.isLocked,
    required this.mode,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamHeader(
          id: '05',
          name: 'LIMIT',
          command: 'LIM',
          subtitle:
              'Wire-break / short-circuit detection threshold \u00B7 range 0\u20132000 \u00B7 default 0 = off',
        ),
        const SizedBox(height: 8),
        if (mode == '195')
          NumericStepperCard(
            title: 'Global Input Limit',
            command: 'LIM',
            value: draft.limGlobal,
            min: 0,
            max: 2000,
            step: 50,
            onChanged: isLocked ? (_) {} : draftNotifier.setLimGlobal,
            enabled: !isLocked,
          )
        else ...[
          NumericStepperCard(
            title: 'Channel A Limit',
            command: 'LIM:A',
            value: draft.limA,
            min: 0,
            max: 2000,
            step: 50,
            onChanged: isLocked ? (_) {} : draftNotifier.setLimA,
            enabled: !isLocked,
          ),
          NumericStepperCard(
            title: 'Channel B Limit',
            command: 'LIM:B',
            value: draft.limB,
            min: 0,
            max: 2000,
            step: 50,
            onChanged: isLocked ? (_) {} : draftNotifier.setLimB,
            enabled: !isLocked,
          ),
        ],
        Text(
          'Expert parameter: enter the raw integer (0\u20132000). Threshold for command-signal wire-break / short-circuit detection; 0 disables supervision.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _Param06Pol extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  final String mode;
  const _Param06Pol({
    required this.draft,
    required this.draftNotifier,
    required this.isLocked,
    required this.mode,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamHeader(
          id: '06',
          name: 'POL',
          command: 'POL',
          subtitle: 'Signal polarity',
        ),
        const SizedBox(height: 8),
        if (mode == '195')
          PolarityCard(
            label: 'Global polarity',
            command: 'POL',
            currentValue: draft.polGlobal,
            onChanged: isLocked ? (_) {} : draftNotifier.setPolGlobal,
            enabled: !isLocked,
          )
        else ...[
          PolarityCard(
            label: 'Channel A polarity',
            command: 'POL:A',
            currentValue: draft.polA,
            onChanged: isLocked ? (_) {} : draftNotifier.setPolA,
            enabled: !isLocked,
          ),
          PolarityCard(
            label: 'Channel B polarity',
            command: 'POL:B',
            currentValue: draft.polB,
            onChanged: isLocked ? (_) {} : draftNotifier.setPolB,
            enabled: !isLocked,
          ),
        ],
      ],
    );
  }
}

class _Param09Min extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  const _Param09Min({
    required this.draft,
    required this.draftNotifier,
    required this.isLocked,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ParamHeader(
          id: '09',
          name: 'MIN',
          command: 'MIN',
          subtitle:
              'Minimum command floor (spool overlap compensation) \nrange 0\u20136000 \u00B7 default 0',
        ),
        const SizedBox(height: 8),
        NumericStepperCard(
          title: 'Channel A',
          command: 'MIN:A',
          value: draft.minA,
          min: 0,
          max: 6000,
          step: 50,
          onChanged: isLocked ? (_) {} : draftNotifier.setMinA,
          enabled: !isLocked,
          warningText:
              'Value above 3000 (\u2248 30%) can cause abrupt starting jumps.',
          warningThreshold: 3000,
        ),
        NumericStepperCard(
          title: 'Channel B',
          command: 'MIN:B',
          value: draft.minB,
          min: 0,
          max: 6000,
          step: 50,
          onChanged: isLocked ? (_) {} : draftNotifier.setMinB,
          enabled: !isLocked,
          warningText:
              'Value above 3000 (\u2248 30%) can cause abrupt starting jumps.',
          warningThreshold: 3000,
        ),
      ],
    );
  }
}

class _Param10Max extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  const _Param10Max({
    required this.draft,
    required this.draftNotifier,
    required this.isLocked,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ParamHeader(
          id: '10',
          name: 'MAX',
          command: 'MAX',
          subtitle:
              'Maximum solenoid output scaling \u00B7 range 5000\u201310000 \u00B7 default 10000',
        ),
        const SizedBox(height: 8),
        NumericStepperCard(
          title: 'Channel A',
          command: 'MAX:A',
          value: draft.maxA,
          min: 5000,
          max: 10000,
          step: 50,
          onChanged: isLocked ? (_) {} : draftNotifier.setMaxA,
          enabled: !isLocked,
        ),
        NumericStepperCard(
          title: 'Channel B',
          command: 'MAX:B',
          value: draft.maxB,
          min: 5000,
          max: 10000,
          step: 50,
          onChanged: isLocked ? (_) {} : draftNotifier.setMaxB,
          enabled: !isLocked,
        ),
      ],
    );
  }
}

class _Param12DitherAmp extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  final String mode;
  const _Param12DitherAmp({
    required this.draft,
    required this.draftNotifier,
    required this.isLocked,
    required this.mode,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamHeader(
          id: '12',
          name: 'Dither Amplitude',
          command: 'DAMPL',
          subtitle:
              'Superimposed anti-stiction dither \u00B7 range 0\u20133000 \u00B7 default 500',
        ),
        const SizedBox(height: 8),
        if (mode == '195')
          NumericStepperCard(
            title: 'Global amplitude',
            command: 'DAMPL',
            value: draft.ditherAmpGlobal,
            min: 0,
            max: 3000,
            step: 50,
            onChanged: isLocked ? (_) {} : draftNotifier.setDitherAmpGlobal,
            enabled: !isLocked,
          )
        else ...[
          NumericStepperCard(
            title: 'Channel A',
            command: 'DAMPL:A',
            value: draft.ditherAmpA,
            min: 0,
            max: 3000,
            step: 50,
            onChanged: isLocked ? (_) {} : draftNotifier.setDitherAmpA,
            enabled: !isLocked,
          ),
          NumericStepperCard(
            title: 'Channel B',
            command: 'DAMPL:B',
            value: draft.ditherAmpB,
            min: 0,
            max: 3000,
            step: 50,
            onChanged: isLocked ? (_) {} : draftNotifier.setDitherAmpB,
            enabled: !isLocked,
          ),
        ],
        Text(
          'Raw integer (0\u20133000). Output estimate = value \u00F7 100 \u00D7 nominal coil current (1000 mA). Changing CURRENT auto-rescales this parameter proportionally.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _Param13DitherFreq extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  final String mode;
  const _Param13DitherFreq({
    required this.draft,
    required this.draftNotifier,
    required this.isLocked,
    required this.mode,
  });
  @override
  Widget build(BuildContext context) {
    // Consume the discrete PAM value set from the static parameter
    // definition (ParamDef.supportedValues) rather than hard-coding it here
    // \u2014 see param_supported_values.dart for the hardware-characterized list.
    final supportedValues = kParamDefs
        .firstWhere((p) => p.id == '13')
        .supportedValues!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamHeader(
          id: '13',
          name: 'Dither Frequency',
          command: 'DFREQ',
          subtitle:
              'Anti-stiction dither carrier \u00B7 ${supportedValues.length} PAM-supported values \u00B7 default 121 Hz',
        ),
        const SizedBox(height: 8),
        if (mode == '195')
          DropdownValueCard(
            title: 'Global',
            command: 'DFREQ',
            value: draft.ditherFreqGlobal,
            options: supportedValues,
            unit: 'Hz',
            onChanged: isLocked ? (_) {} : draftNotifier.setDitherFreqGlobal,
            enabled: !isLocked,
          )
        else ...[
          DropdownValueCard(
            title: 'Channel A',
            command: 'DFREQ:A',
            value: draft.ditherFreqA,
            options: supportedValues,
            unit: 'Hz',
            onChanged: isLocked ? (_) {} : draftNotifier.setDitherFreqA,
            enabled: !isLocked,
          ),
          DropdownValueCard(
            title: 'Channel B',
            command: 'DFREQ:B',
            value: draft.ditherFreqB,
            options: supportedValues,
            unit: 'Hz',
            onChanged: isLocked ? (_) {} : draftNotifier.setDitherFreqB,
            enabled: !isLocked,
          ),
        ],
      ],
    );
  }
}

class _Param14PWM extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  final String mode;
  const _Param14PWM({
    required this.draft,
    required this.draftNotifier,
    required this.isLocked,
    required this.mode,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamHeader(
          id: '14',
          name: 'PWM Frequency',
          command: mode == '196' ? 'PWM:A \u00B7 PWM:B' : 'PWM',
          subtitle:
              'Switching frequency, strict discrete steps \u00B7 default 2604 Hz',
        ),
        const SizedBox(height: 8),
        if (mode == '196') ...[
          _PWMField(
            label: 'Channel A',
            value: draft.pwmA,
            onChanged: isLocked ? (_) {} : draftNotifier.setPwmA,
            enabled: !isLocked,
          ),
          _PWMField(
            label: 'Channel B',
            value: draft.pwmB,
            onChanged: isLocked ? (_) {} : draftNotifier.setPwmB,
            enabled: !isLocked,
          ),
        ] else
          _PWMField(
            label: 'Global carrier',
            value: draft.pwmGlobal,
            onChanged: isLocked ? (_) {} : draftNotifier.setPwmGlobal,
            enabled: !isLocked,
          ),
      ],
    );
  }
}

class _PWMField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;
  const _PWMField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });
  static const List<int> _pwmSteps = [
    61,
    72,
    85,
    100,
    120,
    150,
    200,
    269,
    372,
    488,
    624,
    781,
    976,
    1201,
    1420,
    1562,
    1736,
    1953,
    2232,
    2604,
  ];
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$label  PWM',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
                    'Hz',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
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
                  value: value,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  items: _pwmSteps
                      .map(
                        (hz) =>
                            DropdownMenuItem(value: hz, child: Text('$hz Hz')),
                      )
                      .toList(),
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
