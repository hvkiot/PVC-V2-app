part of '../advanced_config_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  INDIVIDUAL PARAMETER RENDERERS
// ════════════════════════════════════════════════════════════════════════════

class _Param01Function extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  const _Param01Function({
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
          id: '01',
          name: 'Function',
          command: 'FUNCTION',
          subtitle: 'Controller behaviour mode',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected function',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: draft.func,
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '195',
                          child: Text('195 \u2014 Single Directional Valve'),
                        ),
                        DropdownMenuItem(
                          value: '196',
                          child: Text('196 \u2014 Two Independent Valves'),
                        ),
                      ],
                      onChanged: isLocked
                          ? null
                          : (v) {
                              if (v != null) draftNotifier.setFunc(v);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Applies after Save to Memory with confirmation.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Param02Sens extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  const _Param02Sens({
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
          id: '02',
          name: 'SENS',
          command: 'SENS',
          subtitle: 'Sensor supervision mode \u00B7 default AUTO',
        ),
        const SizedBox(height: 8),
        SegmentedCard(
          title: 'Sensor supervision',
          command: 'SENS',
          options: const ['ON', 'OFF', 'AUTO'],
          currentValue: draft.sens,
          onChanged: isLocked ? (_) {} : draftNotifier.setSens,
          enabled: !isLocked,
        ),
        const HelpCard(
          title: 'Wire-break protection.',
          message:
              'While SENS is ON or AUTO, a detected solenoid wire break immediately shuts off the output-stage current and drops the physical READY output (PIN 5) to OFF.',
        ),
      ],
    );
  }
}

class _Param03CCMode extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  const _Param03CCMode({
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
          id: '03',
          name: 'CC Mode',
          command: 'CCMODE',
          subtitle: 'Closed-loop control mode \u00B7 default OFF',
        ),
        const SizedBox(height: 8),
        SegmentedCard(
          title: 'Control mode',
          command: 'CCMODE',
          options: const ['ON', 'OFF'],
          currentValue: draft.ccMode ? 'ON' : 'OFF',
          onChanged: isLocked
              ? (_) {}
              : (v) => draftNotifier.setCcMode(v == 'ON'),
          enabled: !isLocked,
          helpText:
              'ON: output follows the 10-point linearization curve held in PAM DATA. OFF: direct linear mapping.',
        ),
      ],
    );
  }
}

class _Param04EnableB extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  final String mode;
  const _Param04EnableB({
    required this.draft,
    required this.draftNotifier,
    required this.isLocked,
    required this.mode,
  });
  @override
  Widget build(BuildContext context) {
    if (mode != '196') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ParamHeader(
            id: '04',
            name: 'Enable-B',
            command: 'ENABLE_B',
            subtitle: 'Channel B enable source',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Enable-B is only applicable for FUNCTION 196. Currently running FUNCTION $mode.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ParamHeader(
          id: '04',
          name: 'Enable-B',
          command: 'ENABLE_B',
          subtitle: 'Channel B enable source \u00B7 default OFF',
        ),
        const SizedBox(height: 8),
        SegmentedCard(
          title: 'Channel B enable',
          command: 'ENABLE_B',
          options: const ['ON', 'OFF'],
          currentValue: draft.enableB ? 'ON' : 'OFF',
          onChanged: isLocked
              ? (_) {}
              : (v) => draftNotifier.setEnableB(v == 'ON'),
          enabled: !isLocked,
          helpText:
              'ON: PIN 15\u2192Ch A, PIN 6\u2192Ch B. OFF: PIN 15 globally enables both.',
        ),
      ],
    );
  }
}

class _Param11Trigger extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  const _Param11Trigger({
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
          id: '11',
          name: 'Trigger',
          command: 'TRIGGER',
          subtitle:
              'Command activation threshold \u00B7 range 0\u20133000 \u00B7 default 200',
        ),
        const SizedBox(height: 8),
        NumericStepperCard(
          title: 'Trigger threshold',
          command: 'TRIGGER',
          value: draft.trigger,
          min: 0,
          max: 3000,
          step: 50,
          onChanged: isLocked ? (_) {} : draftNotifier.setTrigger,
          enabled: !isLocked,
        ),
      ],
    );
  }
}
