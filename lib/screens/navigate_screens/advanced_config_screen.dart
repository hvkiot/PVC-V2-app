import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/models/advanced_config_state.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/utils/machine_utils.dart';
import 'package:pvc_v2/utils/responsive_helper.dart';
import 'package:pvc_v2/widgets/parameter_widgets.dart';

class AdvancedConfigScreen extends ConsumerStatefulWidget {
  const AdvancedConfigScreen({super.key});

  @override
  ConsumerState<AdvancedConfigScreen> createState() =>
      _AdvancedConfigScreenState();
}

class _AdvancedConfigScreenState extends ConsumerState<AdvancedConfigScreen> {
  bool _isSynchronizing = false;

  // ── Timing constants ──────────────────────────────────────────────────────
  // Same backstop durations as ConfigScreen / InputScreen.
  // ignore: unused_field
  static const Duration _ackTimeout = Duration(seconds: 3);
  // ignore: unused_field
  static const Duration _doneTimeoutFunctionChange = Duration(seconds: 10);
  // ignore: unused_field
  static const Duration _doneTimeoutParameterChange = Duration(seconds: 4);

  // ── Transition wait helpers ────────────────────────────────────────────────
  // ignore: unused_element
  Future<bool> _waitForTransition(Duration doneTimeout) async {
    final ackStart = DateTime.now();
    bool seenTrue = false;
    while (DateTime.now().difference(ackStart) < _ackTimeout) {
      if (ref.read(machineDataProvider).transition) {
        seenTrue = true;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (seenTrue) return _waitForDone(doneTimeout);
    if (!ref.read(machineDataProvider).transition) return true;
    return _waitForDone(doneTimeout);
  }

  Future<bool> _waitForDone(Duration doneTimeout) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < doneTimeout) {
      if (!ref.read(machineDataProvider).transition) return true;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  void _saveConfig() {
    // Phase 2: BLE write path — not wired yet.
    setState(() => _isSynchronizing = true);

    // Simulate a quick save for UI-only preview
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _isSynchronizing = false);
      ref
          .read(globalMessageProvider.notifier)
          .showSuccess('Parameter saved (UI-only preview)');
    });
  }

  // ── Parameter selection sheet ──────────────────────────────────────────────
  void _openParamSheet() {
    final theme = Theme.of(context);
    final state = ref.read(advancedConfigProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Parameter',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: kParamDefs.length,
                  itemBuilder: (ctx, i) {
                    final p = kParamDefs[i];
                    final isSelected = p.id == state.selectedParam;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primaryContainer,
                        child: Text(
                          p.id,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        p.command,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        ref
                            .read(advancedConfigProvider.notifier)
                            .selectParam(p.id);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final machineData = ref.watch(machineDataProvider);
    final advState = ref.watch(advancedConfigProvider);
    final advNotifier = ref.read(advancedConfigProvider.notifier);
    final isBusy = ref.watch(bleProvider).isBusy;

    final String mode = machineData.func;
    final bool isPinActive = machineData.pin15 || machineData.pin6;
    final bool isLocked = isPinActive || isBusy || _isSynchronizing;

    final paramDef = kParamDefs.firstWhere(
      (p) => p.id == advState.selectedParam,
      orElse: () => kParamDefs[0],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ResponsiveWrapper(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Master parameter selector ──
                _MasterSelector(
                  currentId: advState.selectedParam,
                  paramDef: paramDef,
                  onTap: _openParamSheet,
                ),
                const SizedBox(height: 12),

                // ── PIN status ──
                SafetyBanner(
                  pinLabel: activePinsLabel(
                    machineData.pin15,
                    machineData.pin6,
                  ),
                  isActive: isPinActive,
                ),
                if (isPinActive) const SizedBox(height: 12),

                // ── Dynamic parameter form ──
                _buildParamForm(advState, advNotifier, isLocked, mode),
                const SizedBox(height: 20),

                // ── Save button ──
                ElevatedButton(
                  onPressed: !isLocked ? _saveConfig : null,
                  child: Text(
                    _isSynchronizing ? 'Synchronizing...' : 'Save to Memory',
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PARAMETER FORM DISPATCHER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildParamForm(
    AdvancedConfigState state,
    AdvancedConfigNotifier notifier,
    bool isLocked,
    String mode,
  ) {
    switch (state.selectedParam) {
      case '01':
        return _Param01Function(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
        );
      case '02':
        return _Param02Sens(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
        );
      case '03':
        return _Param03CCMode(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
        );
      case '04':
        return _Param04EnableB(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '05':
        return _Param05Limit(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '06':
        return _Param06Pol(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '07':
        return _Param07AIN(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '08':
        return _Param08Ramp(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '09':
        return _Param09Min(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
        );
      case '10':
        return _Param10Max(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
        );
      case '11':
        return _Param11Trigger(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
        );
      case '12':
        return _Param12DitherAmp(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '13':
        return _Param13DitherFreq(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '14':
        return _Param14PWM(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '15':
        return _Param15Current(
          state: state,
          notifier: notifier,
          isLocked: isLocked,
          mode: mode,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TOP-LEVEL WIDGETS
// ════════════════════════════════════════════════════════════════════════════

/// Master parameter selector — tappable card with chevron.
class _MasterSelector extends StatelessWidget {
  final String currentId;
  final ParamDef paramDef;
  final VoidCallback onTap;

  const _MasterSelector({
    required this.currentId,
    required this.paramDef,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                'Parameter',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '$currentId \u00B7 ${paramDef.name}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  INDIVIDUAL PARAMETER RENDERERS
// ════════════════════════════════════════════════════════════════════════════

class _Param01Function extends StatelessWidget {
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;

  const _Param01Function({
    required this.state,
    required this.notifier,
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
                      value: state.func,
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
                              if (v != null) notifier.setFunc(v);
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
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;

  const _Param02Sens({
    required this.state,
    required this.notifier,
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
          groupLabel: 'STD',
          groupColor: Color(0xFFE4F1E7),
          command: 'SENS',
          subtitle: 'Sensor supervision mode \u00B7 default AUTO',
        ),
        const SizedBox(height: 8),
        SegmentedCard(
          title: 'Sensor supervision',
          command: 'SENS',
          options: const ['ON', 'OFF', 'AUTO'],
          currentValue: state.sens,
          onChanged: isLocked ? (_) {} : notifier.setSens,
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
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;

  const _Param03CCMode({
    required this.state,
    required this.notifier,
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
          groupLabel: 'EXP',
          groupColor: Color(0xFFFDECE3),
          command: 'CCMODE',
          subtitle: 'Closed-loop control mode \u00B7 default OFF',
        ),
        const SizedBox(height: 8),
        SegmentedCard(
          title: 'Control mode',
          command: 'CCMODE',
          options: const ['ON', 'OFF'],
          currentValue: state.ccMode ? 'ON' : 'OFF',
          onChanged: isLocked ? (_) {} : (v) => notifier.setCcMode(v == 'ON'),
          enabled: !isLocked,
          helpText:
              'ON: output follows the 10-point linearization curve held in PAM DATA. OFF: direct linear mapping.',
        ),
      ],
    );
  }
}

class _Param04EnableB extends StatelessWidget {
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;
  final String mode;

  const _Param04EnableB({
    required this.state,
    required this.notifier,
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
            groupLabel: 'EXP',
            groupColor: Color(0xFFFDECE3),
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
          groupLabel: 'EXP',
          groupColor: Color(0xFFFDECE3),
          command: 'ENABLE_B',
          subtitle: 'Channel B enable source \u00B7 default OFF',
        ),
        const SizedBox(height: 8),
        SegmentedCard(
          title: 'Channel B enable',
          command: 'ENABLE_B',
          options: const ['ON', 'OFF'],
          currentValue: state.enableB ? 'ON' : 'OFF',
          onChanged: isLocked ? (_) {} : (v) => notifier.setEnableB(v == 'ON'),
          enabled: !isLocked,
          helpText:
              'ON: PIN 15\u2192Ch A, PIN 6\u2192Ch B. OFF: PIN 15 globally enables both.',
        ),
      ],
    );
  }
}

class _Param05Limit extends StatelessWidget {
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;
  final String mode;

  const _Param05Limit({
    required this.state,
    required this.notifier,
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
          groupLabel: 'EXP',
          groupColor: const Color(0xFFFDECE3),
          command: 'LIM',
          subtitle:
              'Wire-break / short-circuit detection threshold \u00B7 range 0\u20132000 \u00B7 default 0 = off',
        ),
        const SizedBox(height: 8),
        if (mode == '195')
          NumericStepperCard(
            title: 'Global Input Limit',
            command: 'LIM',
            value: state.limGlobal,
            min: 0,
            max: 2000,
            step: 50,
            onChanged: isLocked ? (_) {} : notifier.setLimGlobal,
            enabled: !isLocked,
          )
        else ...[
          NumericStepperCard(
            title: 'Channel A Limit',
            command: 'LIM:A',
            value: state.limA,
            min: 0,
            max: 2000,
            step: 50,
            onChanged: isLocked ? (_) {} : notifier.setLimA,
            enabled: !isLocked,
          ),
          NumericStepperCard(
            title: 'Channel B Limit',
            command: 'LIM:B',
            value: state.limB,
            min: 0,
            max: 2000,
            step: 50,
            onChanged: isLocked ? (_) {} : notifier.setLimB,
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
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;
  final String mode;

  const _Param06Pol({
    required this.state,
    required this.notifier,
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
          groupLabel: 'STD',
          groupColor: const Color(0xFFE4F1E7),
          command: 'POL',
          subtitle: 'Signal polarity',
        ),
        const SizedBox(height: 8),
        if (mode == '195')
          PolarityCard(
            label: 'Global polarity',
            command: 'POL',
            currentValue: state.polGlobal,
            onChanged: isLocked ? (_) {} : notifier.setPolGlobal,
            enabled: !isLocked,
          )
        else ...[
          PolarityCard(
            label: 'Channel A polarity',
            command: 'POL:A',
            currentValue: state.polA,
            onChanged: isLocked ? (_) {} : notifier.setPolA,
            enabled: !isLocked,
          ),
          PolarityCard(
            label: 'Channel B polarity',
            command: 'POL:B',
            currentValue: state.polB,
            onChanged: isLocked ? (_) {} : notifier.setPolB,
            enabled: !isLocked,
          ),
        ],
      ],
    );
  }
}

class _Param07AIN extends StatelessWidget {
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;
  final String mode;

  const _Param07AIN({
    required this.state,
    required this.notifier,
    required this.isLocked,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final dual = mode == '196';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamHeader(
          id: '07',
          name: 'AIN',
          groupLabel: 'EXP',
          groupColor: const Color(0xFFFDECE3),
          command: dual ? 'AIN:A \u00B7 AIN:B' : 'AIN:A',
          subtitle: 'Command input type and scaling',
        ),
        const SizedBox(height: 8),
        TabbedPanelCard(
          title: '',
          command: '',
          tabLabels: const ['Input Type', 'Advanced Scaling'],
          selectedTab: state.ainAdvancedTab ? 1 : 0,
          onTabChanged: isLocked
              ? (_) {}
              : (_) => notifier.toggleAinAdvancedTab(),
          enabled: !isLocked,
          tabChildren: [
            // Tab 1: Input Type
            Column(
              children: [
                SegmentedCard(
                  title: 'Channel A input',
                  command: 'AIN:A',
                  options: const ['V', 'C'],
                  currentValue: state.ainAType,
                  onChanged: isLocked ? (_) {} : notifier.setAinAType,
                  enabled: !isLocked,
                  helpText:
                      'V = voltage \u00B110V differential \u00B7 C = current loop 4\u201320 mA (internal 390\u03A9 shunt engages automatically).',
                ),
                if (dual)
                  SegmentedCard(
                    title: 'Channel B input',
                    command: 'AIN:B',
                    options: const ['V', 'C'],
                    currentValue: state.ainBType,
                    onChanged: isLocked ? (_) {} : notifier.setAinBType,
                    enabled: !isLocked,
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'FUNCTION 195 uses a single command input; AIN:B does not exist in this mode.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            // Tab 2: Advanced Scaling
            Column(
              children: [
                if (dual) ...[
                  AINScalingRow(
                    label: 'Channel A scaling (A)',
                    valueA: state.ainAa,
                    valueB: state.ainAb,
                    valueC: state.ainAc,
                    onAChanged: isLocked ? (_) {} : notifier.setAinAa,
                    onBChanged: isLocked ? (_) {} : notifier.setAinAb,
                    onCChanged: isLocked ? (_) {} : notifier.setAinAc,
                    enabled: !isLocked,
                  ),
                  AINScalingRow(
                    label: 'Channel B scaling (B)',
                    valueA: state.ainBa,
                    valueB: state.ainBb,
                    valueC: state.ainBc,
                    onAChanged: isLocked ? (_) {} : notifier.setAinBa,
                    onBChanged: isLocked ? (_) {} : notifier.setAinBb,
                    onCChanged: isLocked ? (_) {} : notifier.setAinBc,
                    enabled: !isLocked,
                  ),
                ] else
                  AINScalingRow(
                    label: 'Input scaling',
                    valueA: state.ainAa,
                    valueB: state.ainAb,
                    valueC: state.ainAc,
                    onAChanged: isLocked ? (_) {} : notifier.setAinAa,
                    onBChanged: isLocked ? (_) {} : notifier.setAinAb,
                    onCChanged: isLocked ? (_) {} : notifier.setAinAc,
                    enabled: !isLocked,
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Param08Ramp extends StatelessWidget {
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;
  final String mode;

  const _Param08Ramp({
    required this.state,
    required this.notifier,
    required this.isLocked,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final rows = mode == '195'
        ? [
            ('Solenoid A Accel', 'AA:1', state.rampAaUp, notifier.setRampAaUp),
            (
              'Solenoid A Decel',
              'AA:2',
              state.rampAaDown,
              notifier.setRampAaDown,
            ),
            ('Solenoid B Accel', 'AA:3', state.rampAbUp, notifier.setRampAbUp),
            (
              'Solenoid B Decel',
              'AA:4',
              state.rampAbDown,
              notifier.setRampAbDown,
            ),
          ]
        : [
            ('Channel A Up', 'AA:UP', state.rampAaUp, notifier.setRampAaUp),
            (
              'Channel A Down',
              'AA:DOWN',
              state.rampAaDown,
              notifier.setRampAaDown,
            ),
            ('Channel B Up', 'AB:UP', state.rampAbUp, notifier.setRampAbUp),
            (
              'Channel B Down',
              'AB:DOWN',
              state.rampAbDown,
              notifier.setRampAbDown,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ParamHeader(
          id: '08',
          name: 'Ramp',
          groupLabel: 'STD',
          groupColor: Color(0xFFE4F1E7),
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

class _Param09Min extends StatelessWidget {
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;

  const _Param09Min({
    required this.state,
    required this.notifier,
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
          groupLabel: 'STD',
          groupColor: Color(0xFFE4F1E7),
          command: 'MIN',
          subtitle:
              'Minimum command floor (spool overlap compensation) \u00B7 range 0\u20136000 \u00B7 default 0',
        ),
        const SizedBox(height: 8),
        NumericStepperCard(
          title: 'Channel A',
          command: 'MIN:A',
          value: state.minA,
          min: 0,
          max: 6000,
          step: 50,
          onChanged: isLocked ? (_) {} : notifier.setMinA,
          enabled: !isLocked,
          warningText:
              'Value above 3000 (\u2248 30%) can cause abrupt starting jumps.',
          warningThreshold: 3000,
        ),
        NumericStepperCard(
          title: 'Channel B',
          command: 'MIN:B',
          value: state.minB,
          min: 0,
          max: 6000,
          step: 50,
          onChanged: isLocked ? (_) {} : notifier.setMinB,
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
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;

  const _Param10Max({
    required this.state,
    required this.notifier,
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
          groupLabel: 'STD',
          groupColor: Color(0xFFE4F1E7),
          command: 'MAX',
          subtitle:
              'Maximum solenoid output scaling \u00B7 range 5000\u201310000 \u00B7 default 10000',
        ),
        const SizedBox(height: 8),
        NumericStepperCard(
          title: 'Channel A',
          command: 'MAX:A',
          value: state.maxA,
          min: 5000,
          max: 10000,
          step: 50,
          onChanged: isLocked ? (_) {} : notifier.setMaxA,
          enabled: !isLocked,
        ),
        NumericStepperCard(
          title: 'Channel B',
          command: 'MAX:B',
          value: state.maxB,
          min: 5000,
          max: 10000,
          step: 50,
          onChanged: isLocked ? (_) {} : notifier.setMaxB,
          enabled: !isLocked,
        ),
      ],
    );
  }
}

class _Param11Trigger extends StatelessWidget {
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;

  const _Param11Trigger({
    required this.state,
    required this.notifier,
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
          groupLabel: 'STD',
          groupColor: Color(0xFFE4F1E7),
          command: 'TRIGGER',
          subtitle:
              'Command activation threshold \u00B7 range 0\u20133000 \u00B7 default 200',
        ),
        const SizedBox(height: 8),
        NumericStepperCard(
          title: 'Trigger threshold',
          command: 'TRIGGER',
          value: state.trigger,
          min: 0,
          max: 3000,
          step: 50,
          onChanged: isLocked ? (_) {} : notifier.setTrigger,
          enabled: !isLocked,
        ),
      ],
    );
  }
}

class _Param12DitherAmp extends StatelessWidget {
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;
  final String mode;

  const _Param12DitherAmp({
    required this.state,
    required this.notifier,
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
          groupLabel: 'STD',
          groupColor: const Color(0xFFE4F1E7),
          command: 'DAMPL',
          subtitle:
              'Superimposed anti-stiction dither \u00B7 range 0\u20133000 \u00B7 default 500',
        ),
        const SizedBox(height: 8),
        if (mode == '195')
          NumericStepperCard(
            title: 'Global amplitude',
            command: 'DAMPL',
            value: state.ditherAmpGlobal,
            min: 0,
            max: 3000,
            step: 50,
            onChanged: isLocked ? (_) {} : notifier.setDitherAmpGlobal,
            enabled: !isLocked,
          )
        else ...[
          NumericStepperCard(
            title: 'Channel A',
            command: 'DAMPL:A',
            value: state.ditherAmpA,
            min: 0,
            max: 3000,
            step: 50,
            onChanged: isLocked ? (_) {} : notifier.setDitherAmpA,
            enabled: !isLocked,
          ),
          NumericStepperCard(
            title: 'Channel B',
            command: 'DAMPL:B',
            value: state.ditherAmpB,
            min: 0,
            max: 3000,
            step: 50,
            onChanged: isLocked ? (_) {} : notifier.setDitherAmpB,
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
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;
  final String mode;

  const _Param13DitherFreq({
    required this.state,
    required this.notifier,
    required this.isLocked,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamHeader(
          id: '13',
          name: 'Dither Frequency',
          groupLabel: 'STD',
          groupColor: const Color(0xFFE4F1E7),
          command: 'DFREQ',
          subtitle: 'Anti-stiction dither carrier \u00B7 default 121 Hz',
        ),
        const SizedBox(height: 8),
        if (mode == '195')
          NumericStepperCard(
            title: 'Global',
            command: 'DFREQ',
            value: state.ditherFreqGlobal,
            min: 60,
            max: 400,
            step: 1,
            unit: 'Hz',
            onChanged: isLocked ? (_) {} : notifier.setDitherFreqGlobal,
            enabled: !isLocked,
          )
        else ...[
          NumericStepperCard(
            title: 'Channel A',
            command: 'DFREQ:A',
            value: state.ditherFreqA,
            min: 60,
            max: 400,
            step: 1,
            unit: 'Hz',
            onChanged: isLocked ? (_) {} : notifier.setDitherFreqA,
            enabled: !isLocked,
          ),
          NumericStepperCard(
            title: 'Channel B',
            command: 'DFREQ:B',
            value: state.ditherFreqB,
            min: 60,
            max: 400,
            step: 1,
            unit: 'Hz',
            onChanged: isLocked ? (_) {} : notifier.setDitherFreqB,
            enabled: !isLocked,
          ),
        ],
      ],
    );
  }
}

class _Param14PWM extends StatelessWidget {
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;
  final String mode;

  const _Param14PWM({
    required this.state,
    required this.notifier,
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
          groupLabel: 'EXP',
          groupColor: const Color(0xFFFDECE3),
          command: mode == '196' ? 'PWM:A \u00B7 PWM:B' : 'PWM',
          subtitle:
              'Switching frequency, strict discrete steps \u00B7 default 2604 Hz',
        ),
        const SizedBox(height: 8),
        if (mode == '196') ...[
          _PWMField(
            label: 'Channel A',
            value: state.pwmA,
            onChanged: isLocked ? (_) {} : notifier.setPwmA,
            enabled: !isLocked,
          ),
          _PWMField(
            label: 'Channel B',
            value: state.pwmB,
            onChanged: isLocked ? (_) {} : notifier.setPwmB,
            enabled: !isLocked,
          ),
        ] else
          _PWMField(
            label: 'Global carrier',
            value: state.pwmGlobal,
            onChanged: isLocked ? (_) {} : notifier.setPwmGlobal,
            enabled: !isLocked,
          ),
        // ACC toggle
        const SizedBox(height: 8),
        SegmentedCard(
          title: 'Auto-Calculate Controller Gains',
          command: 'ACC',
          options: const ['ON', 'OFF'],
          currentValue: state.accOn ? 'ON' : 'OFF',
          onChanged: isLocked ? (_) {} : (v) => notifier.toggleAcc(),
          enabled: !isLocked,
          helpText:
              'PI gains computed automatically for the chosen PWM point. Switch to OFF to enter manual Kp / Ki.',
        ),
        if (!state.accOn) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual PI gains  PPWM / IPWM',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (mode == '196') ...[
                    AINConstantRow(
                      label: 'PPWM:A',
                      value: state.ppwmA,
                      onChanged: (v) => notifier.setPpwmA(v),
                      enabled: !isLocked,
                    ),
                    AINConstantRow(
                      label: 'IPWM:A',
                      value: state.ipwmA,
                      onChanged: (v) => notifier.setIpwmA(v),
                      enabled: !isLocked,
                    ),
                    const SizedBox(height: 8),
                    AINConstantRow(
                      label: 'PPWM:B',
                      value: state.ppwmB,
                      onChanged: (v) => notifier.setPpwmB(v),
                      enabled: !isLocked,
                    ),
                    AINConstantRow(
                      label: 'IPWM:B',
                      value: state.ipwmB,
                      onChanged: (v) => notifier.setIpwmB(v),
                      enabled: !isLocked,
                    ),
                  ] else ...[
                    AINConstantRow(
                      label: 'PPWM',
                      value: state.ppwmGlobal,
                      onChanged: (v) => notifier.setPpwmGlobal(v),
                      enabled: !isLocked,
                    ),
                    AINConstantRow(
                      label: 'IPWM',
                      value: state.ipwmGlobal,
                      onChanged: (v) => notifier.setIpwmGlobal(v),
                      enabled: !isLocked,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        Text(
          'Select from 20 discrete firmware frequencies \u00B7 default 2604 Hz.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  items: _pwmSteps.map((hz) {
                    return DropdownMenuItem(value: hz, child: Text('$hz Hz'));
                  }).toList(),
                  onChanged: enabled
                      ? (v) { if (v != null) onChanged(v); }
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

class _Param15Current extends StatelessWidget {
  final AdvancedConfigState state;
  final AdvancedConfigNotifier notifier;
  final bool isLocked;
  final String mode;

  const _Param15Current({
    required this.state,
    required this.notifier,
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
          groupLabel: 'STD',
          groupColor: const Color(0xFFE4F1E7),
          command: mode == '196' ? 'CURRENT:A \u00B7 CURRENT:B' : 'CURRENT',
          subtitle: 'Nominal solenoid coil current \u00B7 default 1000 mA',
        ),
        const SizedBox(height: 8),
        if (mode == '195')
          NumericStepperCard(
            title: 'Nominal current',
            command: 'CURRENT',
            value: state.currentGlobal,
            min: 500,
            max: 2600,
            step: 50,
            unit: 'mA',
            onChanged: isLocked ? (_) {} : notifier.setCurrentGlobal,
            enabled: !isLocked,
          )
        else ...[
          NumericStepperCard(
            title: 'Channel A current',
            command: 'CURRENT:A',
            value: state.currentA,
            min: 500,
            max: 2600,
            step: 50,
            unit: 'mA',
            onChanged: isLocked ? (_) {} : notifier.setCurrentA,
            enabled: !isLocked,
          ),
          NumericStepperCard(
            title: 'Channel B current',
            command: 'CURRENT:B',
            value: state.currentB,
            min: 500,
            max: 2600,
            step: 50,
            unit: 'mA',
            onChanged: isLocked ? (_) {} : notifier.setCurrentB,
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
