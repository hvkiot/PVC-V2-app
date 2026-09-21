part of '../advanced_config_screen.dart';

class _Param08Ramp extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  final String mode;
  const _Param08Ramp({
    required this.draft,
    required this.draftNotifier,
    required this.isLocked,
    required this.mode,
  });
  @override
  Widget build(BuildContext context) {
    final rows = mode == '195'
        ? [
            (
              'Solenoid A Accel',
              'AA:1',
              draft.rampAaUp,
              draftNotifier.setRampAaUp,
            ),
            (
              'Solenoid A Decel',
              'AA:2',
              draft.rampAaDown,
              draftNotifier.setRampAaDown,
            ),
            (
              'Solenoid B Accel',
              'AA:3',
              draft.rampAbUp,
              draftNotifier.setRampAbUp,
            ),
            (
              'Solenoid B Decel',
              'AA:4',
              draft.rampAbDown,
              draftNotifier.setRampAbDown,
            ),
          ]
        : [
            (
              'Channel A Up',
              'AA:UP',
              draft.rampAaUp,
              draftNotifier.setRampAaUp,
            ),
            (
              'Channel A Down',
              'AA:DOWN',
              draft.rampAaDown,
              draftNotifier.setRampAaDown,
            ),
            (
              'Channel B Up',
              'AB:UP',
              draft.rampAbUp,
              draftNotifier.setRampAbUp,
            ),
            (
              'Channel B Down',
              'AB:DOWN',
              draft.rampAbDown,
              draftNotifier.setRampAbDown,
            ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ParamHeader(
          id: '08',
          name: 'Ramp',
          command: 'AA/AB',
          subtitle: 'Acceleration & deceleration times \u00B7 default 100 ms',
        ),
        const SizedBox(height: 8),
        ...rows.map(
          (r) => RampRow(
            label: r.$1,
            command: r.$2,
            value: r.$3,
            onChanged: isLocked ? (_) {} : r.$4,
            enabled: !isLocked,
          ),
        ),
        Text(
          'Range 1 \u2013 120,000 ms (up to 120 s over a 100% full-scale command step) \u00B7 integers only.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _Param15Current extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  final String mode;
  const _Param15Current({
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
          id: '15',
          name: 'Current',
          command: mode == '196' ? 'CURRENT:A \u00B7 CURRENT:B' : 'CURRENT',
          subtitle: 'Nominal solenoid coil current \u00B7 default 1000 mA',
        ),
        const SizedBox(height: 8),
        if (mode == '195')
          NumericStepperCard(
            title: 'Nominal current',
            command: 'CURRENT',
            value: draft.coilCurrent.round(),
            min: 500,
            max: 2600,
            step: 50,
            unit: 'mA',
            onChanged: isLocked
                ? (_) {}
                : (v) => draftNotifier.setCurrent(v.toDouble()),
            enabled: !isLocked,
          )
        else ...[
          NumericStepperCard(
            title: 'Channel A current',
            command: 'CURRENT:A',
            value: draft.coilACurrent.round(),
            min: 500,
            max: 2600,
            step: 50,
            unit: 'mA',
            onChanged: isLocked
                ? (_) {}
                : (v) => draftNotifier.setCurrentA(v.toDouble()),
            enabled: !isLocked,
          ),
          NumericStepperCard(
            title: 'Channel B current',
            command: 'CURRENT:B',
            value: draft.coilBCurrent.round(),
            min: 500,
            max: 2600,
            step: 50,
            unit: 'mA',
            onChanged: isLocked
                ? (_) {}
                : (v) => draftNotifier.setCurrentB(v.toDouble()),
            enabled: !isLocked,
          ),
        ],
        const HelpCard(
          title: 'Auto-rescaling.',
          message:
              'The output stages regulate up to 2.6 A. When the nominal current changes, parameters that scale with it (MIN, MAX, DAMPL) are updated automatically to keep calibrations proportional.',
        ),
      ],
    );
  }
}
