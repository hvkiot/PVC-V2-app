import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/models/param_supported_values.dart';
import 'package:pvc_v2/providers/advanced_config_draft_provider.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/services/ble_command_controller.dart';
import 'package:pvc_v2/utils/machine_utils.dart';
import 'package:pvc_v2/utils/pvc_debug_trace.dart';
import 'package:pvc_v2/utils/responsive_helper.dart';
import 'package:pvc_v2/widgets/parameter_widgets.dart';
import 'package:pvc_v2/widgets/ain_edit_dialog.dart';

// Re-export param metadata (kept in the old file location for now).
const List<ParamDef> kParamDefs = [
  ParamDef(
    id: '01',
    name: 'Function',
    command: 'FUNCTION',
    group: ParamGroup.general,
  ),
  ParamDef(id: '02', name: 'SENS', command: 'SENS', group: ParamGroup.standard),
  ParamDef(
    id: '03',
    name: 'CC Mode',
    command: 'CCMODE',
    group: ParamGroup.expert,
  ),
  ParamDef(
    id: '04',
    name: 'Enable-B',
    command: 'ENABLE_B',
    group: ParamGroup.expert,
  ),
  ParamDef(id: '05', name: 'LIMIT', command: 'LIM', group: ParamGroup.expert),
  ParamDef(id: '06', name: 'POL', command: 'POL', group: ParamGroup.standard),
  ParamDef(id: '07', name: 'AIN', command: 'AIN', group: ParamGroup.expert),
  ParamDef(
    id: '08',
    name: 'Ramp',
    command: 'AA/AB',
    group: ParamGroup.standard,
  ),
  ParamDef(id: '09', name: 'MIN', command: 'MIN', group: ParamGroup.standard),
  ParamDef(id: '10', name: 'MAX', command: 'MAX', group: ParamGroup.standard),
  ParamDef(
    id: '11',
    name: 'Trigger',
    command: 'TRIGGER',
    group: ParamGroup.standard,
  ),
  ParamDef(
    id: '12',
    name: 'Dither Amplitude',
    command: 'DAMPL',
    group: ParamGroup.standard,
  ),
  ParamDef(
    id: '13',
    name: 'Dither Frequency',
    command: 'DFREQ',
    group: ParamGroup.standard,
    supportedValues: kDitherFrequencySupportedValues,
  ),
  ParamDef(
    id: '14',
    name: 'PWM Frequency',
    command: 'PWM',
    group: ParamGroup.expert,
  ),
  ParamDef(
    id: '15',
    name: 'Current',
    command: 'CURRENT',
    group: ParamGroup.standard,
  ),
];

enum ParamGroup { general, standard, expert }

class ParamDef {
  final String id;
  final String name;
  final String command;
  final ParamGroup group;
  // Discrete PAM-accepted value set, when the parameter isn't a free
  // continuous-step field (e.g. id '13' DFREQ — see param_supported_values.dart).
  // Null for every other (continuous/stepper) parameter — unchanged behavior.
  final List<int>? supportedValues;
  const ParamDef({
    required this.id,
    required this.name,
    required this.command,
    required this.group,
    this.supportedValues,
  });
}

class AdvancedConfigScreen extends ConsumerStatefulWidget {
  const AdvancedConfigScreen({super.key});
  @override
  ConsumerState<AdvancedConfigScreen> createState() =>
      _AdvancedConfigScreenState();
}

class _AdvancedConfigScreenState extends ConsumerState<AdvancedConfigScreen> {
  bool _isSynchronizing = false;
  bool _hasSeeded = false;
  bool _hasRequestedConfigViewExp = false;

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _saveConfig() async {
    final cmd = ref.read(bleCommandProvider);
    final machineData = ref.read(machineDataProvider);
    final draft = ref.read(advancedConfigDraftProvider);
    final messageNotifier = ref.read(globalMessageProvider.notifier);
    final selectedParam = ref.read(selectedAdvancedConfigParamProvider);

    final String mode = machineData.func;

    Future<bool> Function()? writeOp;

    switch (selectedParam) {
      case '01':
        writeOp = () => cmd.writeFunction(draft.func);
        break;
      case '02':
        writeOp = () => cmd.writeSens(draft.sens);
        break;
      case '03':
        writeOp = () => cmd.writeCcMode(draft.ccMode);
        break;
      case '04':
        if (mode != '196') {
          messageNotifier.showError('Enable-B only applies to FUNCTION 196');
          return;
        }
        writeOp = () => cmd.writeEnableB(draft.enableB);
        break;
      case '05':
        writeOp = () => cmd.writeLimit(
          mode: mode,
          global: draft.limGlobal,
          a: draft.limA,
          b: draft.limB,
        );
        break;
      case '06':
        writeOp = () => cmd.writePolarity(
          mode: mode,
          global: draft.polGlobal,
          a: draft.polA,
          b: draft.polB,
        );
        break;
      case '07':
        // Dual-channel writeAIN() diffs each channel and, when both changed,
        // emits ONE grouped AIN196 transaction (write + readback + one SAVE +
        // one D|) in mode 196. Safe in mode 195: the untouched B baseline
        // diffs to nothing, so only the changed channel is ever sent. The old
        // two-call form produced two separate raw FORWARD_RAW transactions
        // (two EEPROM SAVEs, no readback/cache update) that left MachineData
        // stale and kept the Save button armed.
        writeOp = () => cmd.writeAIN(
          channel: 'A',
          a: draft.ainAa,
          b: draft.ainAb,
          c: draft.ainAc,
          // Parameter 07's transmitted <type> is the editable coefficient
          // type, not the live/root AIN type (owned by MachineData.mode —
          // draft.ainAType/ainBType were removed entirely, 2026-09).
          type: draft.ainACoefType,
          bA: draft.ainBa,
          bB: draft.ainBb,
          bC: draft.ainBc,
          bType: draft.ainBCoefType,
        );
        break;
      case '08':
        writeOp = () => cmd.writeRamp(
          mode: mode,
          aUp: draft.rampAaUp,
          aDown: draft.rampAaDown,
          bUp: draft.rampAbUp,
          bDown: draft.rampAbDown,
        );
        break;
      case '09':
        writeOp = () => cmd.writeMin(draft.minA, draft.minB);
        break;
      case '10':
        writeOp = () => cmd.writeMax(draft.maxA, draft.maxB);
        break;
      case '11':
        writeOp = () => cmd.writeTrigger(draft.trigger);
        break;
      case '12':
        writeOp = () => cmd.writeDitherAmplitude(
          mode: mode,
          global: draft.ditherAmpGlobal,
          a: draft.ditherAmpA,
          b: draft.ditherAmpB,
        );
        break;
      case '13':
        writeOp = () => cmd.writeDitherFrequency(
          mode: mode,
          global: draft.ditherFreqGlobal,
          a: draft.ditherFreqA,
          b: draft.ditherFreqB,
        );
        break;
      case '14':
        writeOp = () => cmd.writePwm(
          mode: mode,
          global: draft.pwmGlobal,
          a: draft.pwmA,
          b: draft.pwmB,
        );
        break;
      case '15':
        writeOp = () => cmd.writeCurrent(
          mode: mode,
          single: draft.coilCurrent.round(),
          a: draft.coilACurrent.round(),
          b: draft.coilBCurrent.round(),
        );
        break;
      default:
        writeOp = null;
    }

    if (writeOp == null) {
      messageNotifier.showError('Unknown parameter selected');
      return;
    }

    setState(() => _isSynchronizing = true);

    // The ESP32 now performs the PAM SAVE internally for every user-facing
    // persistent write (handleChangeMode() for FUNCTION, handleSetParam()
    // for tracked params, handleSetCurrent() for standalone CURRENT, and
    // handleForwardRaw()'s AIN:A/AIN:B branch) — so Flutter sends only the
    // selected parameter write and never a separate SAVE command.
    final allSuccess = await writeOp();

    // Lifecycle guard for the FUNCTION 195<->196 + Advanced/EXP race:
    // FUNCTION makes PAM reboot back to PAM_MODE STD mid-transaction
    // (D|PAM_MODE:STD arrives while the write above is still awaiting
    // D|TRANSITION:False). ConfigScreen watches machineDataProvider.pamMode
    // and swaps AdvancedConfigScreen -> BasicConfigScreen on that change,
    // disposing this State while writeOp() is still in flight. writeOp()
    // itself (BleCommandController.execute()) is unaffected by that — it
    // reads machineDataProvider via ref independently of this widget and
    // always runs to completion — only the UI continuation below (setState,
    // draft re-sync, success/error message) must not touch this State once
    // it's gone. When FUNCTION is changed while already in STD (Basic
    // Config), pamMode never flips away from STD, this screen is never the
    // one disposed, mounted stays true, and behavior is unchanged.
    if (!mounted) return;

    setState(() => _isSynchronizing = false);

    if (allSuccess) {
      // Re-sync draft from PAM so Save disables.
      ref
          .read(advancedConfigDraftProvider.notifier)
          .syncFromMachineData(ref.read(machineDataProvider));
      messageNotifier.showSuccess('Settings updated successfully');
    } else {
      messageNotifier.showError('Failed to save settings');
    }
  }

  // ── Parameter selection sheet ──────────────────────────────────────────────
  void _openParamSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // The picker's own ScrollController (created/disposed by, and its
      // initial-position math driven by, _ParamSelectSheet below) replaces
      // the previous Scrollable.ensureVisible attempt — see that widget's
      // doc comment for why ensureVisible didn't work.
      builder: (ctx) => const _ParamSelectSheet(),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final machineData = ref.watch(machineDataProvider);
    final draft = ref.watch(advancedConfigDraftProvider);
    final draftNotifier = ref.read(advancedConfigDraftProvider.notifier);
    final isBusy = ref.watch(bleProvider).isBusy;
    final selectedParam = ref.watch(selectedAdvancedConfigParamProvider);

    // Seed draft from machineData on first real update after connection.
    if (!_hasSeeded && machineData.pamConnected) {
      _hasSeeded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        draftNotifier.seedFromMachineData(machineData);
      });
    }

    // Preserve STD current snapshot across PAM_MODE STD ↔ EXP.
    // The draft is seeded once at connect with the then-current HW values
    // (1000 mA default). If the user later changes STD CURRENT_S/A/B
    // (e.g. 1584 mA) via Basic, MachineData updates, but the already-seeded
    // Advanced draft would remain stale (1000). When PAM_MODE flips, the
    // stale draft would be shown. Re-seed on pamMode change to carry the
    // latest MachineData currents into Parameter 15 (195→CURRENT_S,
    // 196→CURRENT_A/B) — the draft is an editable copy, so overwriting with
    // the authoritative HW snapshot is correct when the mode changes.
    ref.listen<String>(machineDataProvider.select((d) => d.pamMode), (
      prev,
      next,
    ) {
      pvcTrace('PAM_MODE_LISTENER', '$prev -> $next');
      if (prev != null && prev != next && machineData.pamConnected) {
        pvcTrace('DRAFT_SEED_SCHEDULED', '');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            draftNotifier.seedFromMachineData(ref.read(machineDataProvider));
          }
        });
      }
    });

    // One-time CONFIG_VIEW=EXP on Advanced entry — app routing only, not PAM_MODE.
    // Keep CONFIG_VIEW in architecture (F-merge routing) but do not send after each save.
    // Guard ensures already-EXP does not retransmit. At most once per screen instance.
    if (!_hasRequestedConfigViewExp &&
        machineData.pamConnected &&
        machineData.configView != 'EXP') {
      _hasRequestedConfigViewExp = true;
      final expCmd = ref.read(bleCommandProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(expCmd.setConfigView('EXP'));
      });
    }

    final String mode = machineData.func;
    final bool isPinActive = machineData.pin15 || machineData.pin6;
    final bool isLocked = isPinActive || isBusy || _isSynchronizing;
    final bool hasChanges = hasChangesForSelectedParam(
      selectedParam,
      mode,
      draft,
      machineData,
    );

    final paramDef = kParamDefs.firstWhere(
      (p) => p.id == selectedParam,
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
                _MasterSelector(
                  currentId: selectedParam,
                  paramDef: paramDef,
                  onTap: _openParamSheet,
                ),
                const SizedBox(height: 12),
                SafetyBanner(
                  pinLabel: activePinsLabel(
                    machineData.pin15,
                    machineData.pin6,
                  ),
                  isActive: isPinActive,
                ),
                if (isPinActive) const SizedBox(height: 12),
                _buildParamForm(
                  selectedParam,
                  draft,
                  draftNotifier,
                  isLocked,
                  mode,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (hasChanges && !isLocked) ? _saveConfig : null,
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
    String selectedParam,
    AdvancedConfigDraft draft,
    AdvancedConfigDraftNotifier draftNotifier,
    bool isLocked,
    String mode,
  ) {
    switch (selectedParam) {
      case '01':
        return _Param01Function(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
        );
      case '02':
        return _Param02Sens(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
        );
      case '03':
        return _Param03CCMode(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
        );
      case '04':
        return _Param04EnableB(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '05':
        return _Param05Limit(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '06':
        return _Param06Pol(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '07':
        return _Param07AIN(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '08':
        return _Param08Ramp(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '09':
        return _Param09Min(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
        );
      case '10':
        return _Param10Max(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
        );
      case '11':
        return _Param11Trigger(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
        );
      case '12':
        return _Param12DitherAmp(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '13':
        return _Param13DitherFreq(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '14':
        return _Param14PWM(
          draft: draft,
          draftNotifier: draftNotifier,
          isLocked: isLocked,
          mode: mode,
        );
      case '15':
        return _Param15Current(
          draft: draft,
          draftNotifier: draftNotifier,
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

// Fixed ListTile row height for the parameter-select sheet below, used as
// ListView.builder's itemExtent so the initial scroll offset can be
// computed exactly (selectedIndex * itemExtent) rather than measured from
// a built row. Matches Material's standard two-line ListTile height
// (one-line title + one-line subtitle, default vertical padding) that
// these rows already use.
const double _kParamSheetItemExtent = 72.0;

/// Parameter-select bottom sheet content — a dedicated widget (not an
/// inline `builder:` closure) specifically so it can own and correctly
/// dispose a [ScrollController] scoped to this one sheet instance.
///
/// Replaces a previous `Scrollable.ensureVisible()` attempt that did not
/// reliably work: `ListView.builder` only builds/lays out the rows
/// currently within (or very near) its viewport, so a `GlobalKey` on a
/// row far from the top (e.g. parameter 13 or 15, while the sheet opens
/// scrolled to 0) has no `currentContext` yet on the very first post-frame
/// callback — `ensureVisible` had nothing to scroll to and silently did
/// nothing. Jumping to a directly-computed pixel offset has no such
/// dependency: with a fixed [_kParamSheetItemExtent], the target offset for
/// any index is known before any row is built.
class _ParamSelectSheet extends ConsumerStatefulWidget {
  const _ParamSelectSheet();

  @override
  ConsumerState<_ParamSelectSheet> createState() => _ParamSelectSheetState();
}

class _ParamSelectSheetState extends ConsumerState<_ParamSelectSheet> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Runs once, right after this sheet's first layout — not on every
    // rebuild (initState runs exactly once per sheet instance/open).
    WidgetsBinding.instance.addPostFrameCallback(_jumpToSelected);
  }

  void _jumpToSelected(Duration _) {
    if (!mounted || !_scrollController.hasClients) return;
    final currentParam = ref.read(selectedAdvancedConfigParamProvider);
    final selectedIndex = kParamDefs.indexWhere((p) => p.id == currentParam);
    if (selectedIndex < 0) return;

    final position = _scrollController.position;
    final availableListHeight = position.viewportDimension;
    // Center the selected row in the visible list when there's room;
    // clamp handles both ends — param 01 clamps to 0.0, param 15 clamps to
    // maxScrollExtent (bottom of the list) rather than overshooting.
    final targetOffset =
        (selectedIndex * _kParamSheetItemExtent -
                (availableListHeight - _kParamSheetItemExtent) / 2)
            .clamp(0.0, position.maxScrollExtent);
    _scrollController.jumpTo(targetOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Single source of truth, same provider the rest of Advanced Config
    // uses — no separate/competing selection state introduced here.
    final currentParam = ref.watch(selectedAdvancedConfigParamProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              controller: _scrollController,
              itemExtent: _kParamSheetItemExtent,
              shrinkWrap: true,
              itemCount: kParamDefs.length,
              itemBuilder: (ctx, i) {
                final p = kParamDefs[i];
                final isSelected = p.id == currentParam;
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
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : Colors.white,
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
                            .read(selectedAdvancedConfigParamProvider.notifier)
                            .state =
                        p.id;
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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

class _Param07AIN extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  final String mode;
  const _Param07AIN({
    required this.draft,
    required this.draftNotifier,
    required this.isLocked,
    required this.mode,
  });

  Future<void> _openAinDialog(BuildContext context) async {
    final result = await AinEditDialog.show(
      context,
      initialA: draft.ainAa,
      initialB: draft.ainAb,
      initialC: draft.ainAc,
      // Parameter 07 edits the coefficient type, not the live/root AIN type.
      initialX: draft.ainACoefType,
      channelLabel: 'A',
    );
    if (result != null) {
      draftNotifier.setAinAa(result.a);
      draftNotifier.setAinAb(result.b);
      draftNotifier.setAinAc(result.c);
      draftNotifier.setAinACoefType(result.x);
    }
  }

  Future<void> _openAinBDialog(BuildContext context) async {
    final result = await AinEditDialog.show(
      context,
      initialA: draft.ainBa,
      initialB: draft.ainBb,
      initialC: draft.ainBc,
      // Parameter 07 edits the coefficient type, not the live/root AIN type.
      initialX: draft.ainBCoefType,
      channelLabel: 'B',
    );
    if (result != null) {
      draftNotifier.setAinBa(result.a);
      draftNotifier.setAinBb(result.b);
      draftNotifier.setAinBc(result.c);
      draftNotifier.setAinBCoefType(result.x);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dual = mode == '196';
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamHeader(
          id: '07',
          name: 'AIN',
          command: dual ? 'AIN:A \u00B7 AIN:B' : 'AIN:A',
          subtitle: 'Command input type and scaling',
        ),
        const SizedBox(height: 8),
        _buildAinChannelCard(
          context,
          theme,
          label: 'Channel A',
          command: 'AIN:A',
          type: draft.ainACoefType,
          a: draft.ainAa,
          b: draft.ainAb,
          c: draft.ainAc,
          onTap: isLocked ? null : () => _openAinDialog(context),
        ),
        if (dual) ...[
          const SizedBox(height: 8),
          _buildAinChannelCard(
            context,
            theme,
            label: 'Channel B',
            command: 'AIN:B',
            type: draft.ainBCoefType,
            a: draft.ainBa,
            b: draft.ainBb,
            c: draft.ainBc,
            onTap: isLocked ? null : () => _openAinBDialog(context),
          ),
        ],
      ],
    );
  }

  Widget _buildAinChannelCard(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required String command,
    required String type,
    required int a,
    required int b,
    required int c,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
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
                      command,
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
                children: [
                  _buildPill(theme, 'Type', _ainCoefTypeLabel(type)),
                  const SizedBox(width: 8),
                  _buildPill(theme, 'A', a.toString()),
                  const SizedBox(width: 8),
                  _buildPill(theme, 'B', b.toString()),
                  const SizedBox(width: 8),
                  _buildPill(theme, 'C', c.toString()),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Explicit coefficient-type → display-label mapping. Confirmed hardware
  /// behavior: PAM readback does NOT echo the token the app writes — it
  /// reports "U" for voltage and "I" for current (write V -> readback U;
  /// write C -> readback I). "V"/"U" both mean Voltage; "C"/"I" both mean
  /// Current — this raw value (MachineData.expConfig.ainACoefType/
  /// ainBCoefType) is untouched, only the display label is mapped here.
  /// Deliberately NOT `type == 'V' ? 'Voltage' : 'Current'` — that would
  /// show "Current" for an uninitialized/unknown value (e.g. "None",
  /// empty) instead of "Unknown", which is what an unconfirmed coefficient
  /// type actually is.
  String _ainCoefTypeLabel(String type) {
    switch (type) {
      case 'V':
      case 'U':
        return 'Voltage';
      case 'C':
      case 'I':
        return 'Current';
      default:
        return 'Unknown';
    }
  }

  Widget _buildPill(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

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
