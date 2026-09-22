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

// ═══════════════════════════════════════════════════════════════════════
// STRUCTURAL SPLIT (Phase 4, 2026-09): this file is the library root for
// the AdvancedConfigScreen library \u2014 imports, parameter metadata
// (unchanged/uncentralized, per Phase 4 instructions), the screen widget,
// its State class (kept intact \u2014 see rationale below), and `part`
// directives. The 15 per-parameter form widgets, the parameter-select
// bottom sheet, and the master-selector row now live in the
// `advanced_config_screen/` part files. This is a pure code-motion / file
// re-organization: no UI text, layout, styling, validation, command
// string, provider read/watch/listen, draft-seeding, PAM_MODE guard, or
// CONFIG_VIEW behavior changed.
//
// Why `_AdvancedConfigScreenState` was NOT further split: unlike the 15
// parameter-form widgets (each an independent top-level class \u2014 the exact
// shape Phase 2's parameter_widgets.dart split already handled safely),
// `_AdvancedConfigScreenState` is ONE class with a handful of methods
// (`build`, `_buildParamForm`, `_saveConfig`, `_openParamSheet`) that are
// all tightly coupled to Flutter's own `ConsumerState` machinery \u2014
// `context`, `mounted`, `setState`, `widget` \u2014 not to this app's own
// types. Splitting it would require the same private-mixin technique used
// in Phase 3 (ble_command_controller.dart), but redeclaring Flutter
// framework members abstractly in a mixin is far more failure-prone than
// redeclaring this app's own `_md`/`execute()`, and this phase's own
// constraints explicitly warn against using mixins "merely to make the
// file smaller." Extracting the 15 independent form widgets already cuts
// this file from ~1,954 lines to a few hundred without that risk, so the
// State class was left exactly as it was.
//
// `part`/`part of` (not mixins) was the mechanism for every part file
// below, because the extracted widgets are private (`_Param01Function`
// etc.) \u2014 Dart privacy is per-library, and these are only ever
// constructed from `_buildParamForm()` in this root file's State class \u2014
// so `part`/`part of` is what keeps them reachable without making any of
// them public. Nothing needed a mixin: every extracted class is fully
// independent (no cross-file private helper sharing was required this
// time \u2014 e.g. `_PWMField` stayed in the same file as its sole consumer,
// `_Param14PWM`, exactly like Phase 2's `_SmallButton`/`CurrentLoopGainRow`
// pairing).
//
// Public symbols (unchanged since before the split): `AdvancedConfigScreen`
// \u2014 the only symbol `config_screen.dart` (the sole external consumer)
// references. `ParamDef`, `ParamGroup`, and `kParamDefs` are also public
// (not `_`-prefixed) but were already confirmed, repo-wide, to have no
// external consumers \u2014 they stay in this root file, unmoved and
// unmodified, per Phase 4's explicit "do not centralize parameter
// metadata" instruction.
//
// See AGENTS.md "Phase 4 \u2014 AdvancedConfigScreen structural split
// (2026-09)" for the full audit and file-grouping rationale.
// ═══════════════════════════════════════════════════════════════════════

part 'advanced_config_screen/param_selector.dart';
part 'advanced_config_screen/param_forms_simple.dart';
part 'advanced_config_screen/param_forms_diffed.dart';
part 'advanced_config_screen/param_forms_ain.dart';
part 'advanced_config_screen/param_forms_current_ramp.dart';

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
    // machineData/draft are deliberately watched whole here, not narrowed
    // with select() (audited 2026-09, Phase 1 perf pass): hasChangesForSelectedParam()
    // and _buildParamForm() below read whichever machineData/draft fields
    // are relevant to the CURRENTLY SELECTED parameter, and that field set
    // is different for every one of the 15 params (e.g. selecting '05'
    // needs limGlobal/limA/limB, selecting '13' needs ditherFreq*). A
    // select() narrow enough to be a real rebuild win would have to be
    // recomputed per selectedParam, which would mean not rebuilding when an
    // unselected-but-still-relevant field changes underneath the currently
    // shown param — i.e. a stale Save-button/hasChanges bug, not a pure
    // perf change. That's a real optimization opportunity but it needs a
    // per-parameter field map (an architecture change), out of scope for
    // this phase — see AGENTS.md/task history. isBusy IS narrowed below
    // since it has no such per-param coupling.
    final machineData = ref.watch(machineDataProvider);
    final draft = ref.watch(advancedConfigDraftProvider);
    final draftNotifier = ref.read(advancedConfigDraftProvider.notifier);
    // Only isBusy is used from BleState in this screen — select() so a
    // rebuild only happens when isBusy itself actually changes, not on
    // every unrelated BleState field change (scan results, serial log, ...).
    final isBusy = ref.watch(bleProvider.select((s) => s.isBusy));
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // Guard added 2026-09 (Phase 1): re-seeding overwrites the WHOLE
          // draft from MachineData, which would silently discard an
          // in-progress edit on the currently-viewed parameter if PAM_MODE
          // flips mid-edit. Reuses the existing hasChangesForSelectedParam
          // dirty-check (the same one the Save button's `hasChanges` uses)
          // rather than building new dirty-tracking — if the parameter the
          // user is currently looking at has unsaved changes, skip this
          // reseed and leave the draft alone; the listener itself, and every
          // OTHER reseed path (the initial-connect seed above, and any
          // future explicit "sync from hardware" action), are untouched and
          // still reseed normally.
          final freshMachineData = ref.read(machineDataProvider);
          final hasUnsavedEdits = hasChangesForSelectedParam(
            ref.read(selectedAdvancedConfigParamProvider),
            freshMachineData.func,
            ref.read(advancedConfigDraftProvider),
            freshMachineData,
          );
          if (hasUnsavedEdits) {
            pvcTrace('DRAFT_SEED_SKIPPED_UNSAVED', 'pamMode $prev -> $next');
            return;
          }
          pvcTrace('DRAFT_SEED_SCHEDULED', '');
          draftNotifier.seedFromMachineData(freshMachineData);
        });
      }
    });

    // Phase 13: CONFIG_VIEW removed entirely. This screen is only ever
    // shown when MachineData.pamMode == 'EXP' (see ConfigScreen's routing),
    // which is already the single source of truth — no app-preference
    // write is needed on entry.

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
