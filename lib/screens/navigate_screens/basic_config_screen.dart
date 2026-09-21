import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/configuration_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/services/ble_command_controller.dart';
import 'package:pvc_v2/utils/machine_utils.dart';
import 'package:pvc_v2/utils/responsive_helper.dart';
import 'package:pvc_v2/widgets/app_selector_card.dart';
import 'package:pvc_v2/widgets/app_text_card.dart';

/// PVC kit — single unified STD screen.
/// Only three parameters: Function, AINA, Current.
class BasicConfigScreen extends ConsumerStatefulWidget {
  const BasicConfigScreen({super.key});

  @override
  ConsumerState<BasicConfigScreen> createState() => _BasicConfigScreenState();
}

class _BasicConfigScreenState extends ConsumerState<BasicConfigScreen> {
  bool _isSynchronizing = false;

  // ── Save ────────────────────────────────────────────────────────────────
  void _save() async {
    final machineData = ref.read(machineDataProvider);
    final configState = ref.read(configTabProvider);
    final inputsState = ref.read(inputsTabProvider);
    final configNotifier = ref.read(configTabProvider.notifier);
    final inputsNotifier = ref.read(inputsTabProvider.notifier);
    final messageNotifier = ref.read(globalMessageProvider.notifier);
    final bleCommand = ref.read(bleCommandProvider);

    if (machineData.transition) {
      messageNotifier.showError("Device is busy, please wait");
      return;
    }

    // ── Resolve values ───────────────────────────────────────────────────
    final String selectedMode = inputsState.selectedMode ?? machineData.func;
    final String selectedInput =
        inputsState.selectedInput1 ??
        (machineData.mode == 'V' ? 'Voltage' : 'Current');
    final bool modeChanged = selectedMode != machineData.func;

    if (selectedMode == '196') {
      final input2 = inputsState.selectedInput2 ?? selectedInput;
      if (selectedInput.toUpperCase() != input2.toUpperCase()) {
        messageNotifier.showError("Both inputs must match in Mode 196");
        return;
      }
    }

    bool isValid(double val) => val.round() >= 500 && val.round() <= 2600;
    if (selectedMode == '195') {
      final v = configState.coilCurrent > 0
          ? configState.coilCurrent
          : machineData.coilCurrent;
      if (!isValid(v)) {
        messageNotifier.showError("Enter a value between 500 and 2600");
        return;
      }
    } else {
      final a = configState.coilACurrent > 0
          ? configState.coilACurrent
          : machineData.coilACurrent;
      final b = configState.coilBCurrent > 0
          ? configState.coilBCurrent
          : machineData.coilBCurrent;
      if (!isValid(a) || !isValid(b)) {
        messageNotifier.showError("Enter a value between 500 and 2600");
        return;
      }
    }

    // ── Build commands (validation done, now show overlay) ────────────────
    final List<String> commandsToSend = [];
    final String shortUnit = selectedInput.toUpperCase() == 'VOLTAGE'
        ? 'V'
        : 'C';
    final String unit = selectedInput.toUpperCase();
    final String currentInput = machineData.mode == 'V' ? 'VOLTAGE' : 'CURRENT';

    if (modeChanged) {
      // Mode change: build ONE atomic command "196:V:CA:1200:CB:1300".
      // Firmware parses MODE:UNIT[:CA:VAL][:CB:VAL][:CS:VAL] and applies everything
      // in a single PAM transition — no separate CURA/CURB needed.
      final buf = StringBuffer('$selectedMode:$shortUnit');
      if (selectedMode == '195') {
        // Only attach CS if it differs from default 1000
        if (configState.coilCurrent != 1000) {
          buf.write(':CS:${configState.coilCurrent.round()}');
        }
      } else {
        // Only attach CA/CB if they differ from default 1000
        if (configState.coilACurrent != 1000) {
          buf.write(':CA:${configState.coilACurrent.round()}');
        }
        if (configState.coilBCurrent != 1000) {
          buf.write(':CB:${configState.coilBCurrent.round()}');
        }
      }
      commandsToSend.add(buf.toString());
    } else {
      // Standalone input type change (no mode change)
      if (unit != currentInput) {
        commandsToSend.add(unit);
      }

      // Standalone current changes (only when mode is NOT changing)
      if (selectedMode == '195') {
        if (configState.coilCurrent > 0 &&
            configState.coilCurrent.round() !=
                machineData.coilCurrent.round()) {
          commandsToSend.add("CUR:${configState.coilCurrent.round()}:195");
        }
      } else {
        if (configState.coilACurrent > 0 &&
            configState.coilACurrent.round() !=
                machineData.coilACurrent.round()) {
          commandsToSend.add("CURA:${configState.coilACurrent.round()}:196");
        }
        if (configState.coilBCurrent > 0 &&
            configState.coilBCurrent.round() !=
                machineData.coilBCurrent.round()) {
          commandsToSend.add("CURB:${configState.coilBCurrent.round()}:196");
        }
      }
    }

    if (commandsToSend.isEmpty) {
      messageNotifier.showSuccess("Nothing to save");
      return;
    }

    // ── Execute back-to-back ─────────────────────────────────────────────
    // Delegates the write/ack/transition-poll/overlay sequence to the shared
    // BleCommandController (same logic Advanced Config will reuse), so the
    // behavior below is byte-for-byte what the previous inline loop did.
    setState(() => _isSynchronizing = true);

    for (final command in commandsToSend) {
      debugPrint('D| [BasicConfig] Sending command: $command');
    }

    final allSuccess = await bleCommand.execute(
      commandsToSend,
      isModeChange: modeChanged,
    );

    setState(() => _isSynchronizing = false);

    if (allSuccess) {
      configNotifier.reset(0.0, 0.0, 0.0);
      inputsNotifier.reset();
      messageNotifier.showSuccess("Settings updated successfully");
      // Best-effort: record that Basic Config is the last-saved screen.
      // NOTE: no longer what decides which screen ConfigScreen reopens on
      // reconnect (that's MachineData.pamMode now) — configView's remaining
      // job is the F|-snapshot active/inactive section merge routing in
      // MachineData's packet parser. Not awaited — an app-preference cache,
      // not part of the save's success/failure path.
      unawaited(bleCommand.setConfigView('STD'));
    } else {
      messageNotifier.showError("Failed to save settings");
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final machineData = ref.watch(machineDataProvider);
    final configState = ref.watch(configTabProvider);
    final inputsState = ref.watch(inputsTabProvider);
    final theme = Theme.of(context);

    final String mode = machineData.func;
    final bool isPinActive = machineData.pin15 || machineData.pin6;
    final bool isBusy = ref.watch(bleProvider).isBusy;

    final String displayMode = inputsState.selectedMode ?? machineData.func;

    // Reset currents to 1000 mA firmware default when UI mode changes.
    ref.listen<String?>(inputsTabProvider.select((s) => s.selectedMode), (
      prev,
      next,
    ) {
      if (prev != next && next != null) {
        if (next == '195') {
          ref.read(configTabProvider.notifier).reset(1000.0, 0.0, 0.0);
        } else {
          ref.read(configTabProvider.notifier).reset(0.0, 1000.0, 1000.0);
        }
      }
    });

    // Also reset when firmware reports a new mode (after BLE save).
    ref.listen<String>(machineDataProvider.select((d) => d.func), (prev, next) {
      if (prev != null && prev != next) {
        ref.read(inputsTabProvider.notifier).reset();
        if (next == '195') {
          ref.read(configTabProvider.notifier).reset(1000.0, 0.0, 0.0);
        } else {
          ref.read(configTabProvider.notifier).reset(0.0, 1000.0, 1000.0);
        }
      }
    });

    // ── Display values ──────────────────────────────────────────────────────
    final String displayInput =
        inputsState.selectedInput1 ??
        (machineData.mode == 'V' ? 'Voltage' : 'Current');

    // Current: draft wins, hardware is fallback.
    final double displayCurrent;
    if (displayMode == '195') {
      displayCurrent = configState.coilCurrent > 0
          ? configState.coilCurrent
          : machineData.coilCurrent;
    } else {
      displayCurrent = configState.coilACurrent > 0
          ? configState.coilACurrent
          : machineData.coilACurrent;
    }

    // ── Dirty check ─────────────────────────────────────────────────────────
    bool isDirty = false;
    if (inputsState.selectedMode != null &&
        inputsState.selectedMode != machineData.func) {
      isDirty = true;
    }
    if (inputsState.selectedInput1 != null) {
      final currentInput = machineData.mode == 'V' ? 'Voltage' : 'Current';
      if (inputsState.selectedInput1 != currentInput) isDirty = true;
    }
    if (displayMode == '195') {
      if (configState.coilCurrent > 0 &&
          displayCurrent.round() != machineData.coilCurrent.round()) {
        isDirty = true;
      }
    } else {
      final checkA = configState.coilACurrent > 0
          ? configState.coilACurrent
          : machineData.coilACurrent;
      final checkB = configState.coilBCurrent > 0
          ? configState.coilBCurrent
          : machineData.coilBCurrent;
      if (checkA.round() != machineData.coilACurrent.round() ||
          checkB.round() != machineData.coilBCurrent.round()) {
        isDirty = true;
      }
    }

    // ── UI ──────────────────────────────────────────────────────────────────
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
                // ── Mode banner ─────────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'CURRENT MODE: $mode',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        if (isPinActive) ...[
                          const SizedBox(width: 10),
                          Text(
                            '(LOCKED)',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (isPinActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Text(
                      "Device is currently enabled. Disable ${activePinsLabel(machineData.pin15, machineData.pin6)} to modify EEPROM settings",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),

                // ── 1. Function (195/196) ──────────────────────────────────
                AppSelectorCard(
                  title: 'Mode',
                  currentValue: displayMode,
                  options: const ['195', '196'],
                  onChanged: (v) =>
                      ref.read(inputsTabProvider.notifier).setMode(v!),
                  icon: Icons.cable,
                  enabled: !isPinActive && !isBusy,
                ),
                Divider(
                  color: theme.colorScheme.onSurface.withAlpha(25),
                  thickness: 1,
                ),

                // ── 2. AINA (Input type) ───────────────────────────────────
                if (displayMode == '195') ...[
                  AppSelectorCard(
                    title: 'Input',
                    currentValue: displayInput,
                    options: const ['Voltage', 'Current'],
                    onChanged: (v) =>
                        ref.read(inputsTabProvider.notifier).setInput1(v!),
                    icon: Icons.input,
                    enabled: !isPinActive && !isBusy,
                  ),
                ] else ...[
                  AppSelectorCard(
                    title: 'Input 1',
                    currentValue: displayInput,
                    options: const ['Voltage', 'Current'],
                    onChanged: (v) =>
                        ref.read(inputsTabProvider.notifier).setInput1(v!),
                    icon: Icons.input,
                    enabled: !isPinActive && !isBusy,
                  ),
                  Divider(
                    color: theme.colorScheme.onSurface.withAlpha(25),
                    thickness: 1,
                  ),
                  AppSelectorCard(
                    title: 'Input 2',
                    currentValue: displayInput,
                    options: const ['Voltage', 'Current'],
                    onChanged: (v) =>
                        ref.read(inputsTabProvider.notifier).setInput2(v!),
                    icon: Icons.input,
                    enabled: !isPinActive && !isBusy,
                  ),
                ],
                Divider(
                  color: theme.colorScheme.onSurface.withAlpha(25),
                  thickness: 1,
                ),

                // ── 3. Current ──────────────────────────────────────────────
                if (displayMode == '195') ...[
                  AppTextCard(
                    title: 'COIL Output Current',
                    currentValue: displayCurrent,
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(configTabProvider.notifier).setCoilCurrent(v);
                      }
                    },
                    icon: Icons.settings_input_component,
                    enabled: !isPinActive && !isBusy,
                  ),
                ] else ...[
                  AppTextCard(
                    title: 'COIL A Output Current',
                    currentValue: configState.coilACurrent > 0
                        ? configState.coilACurrent
                        : machineData.coilACurrent,
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(configTabProvider.notifier).setCoilACurrent(v);
                      }
                    },
                    icon: Icons.settings_input_component,
                    enabled: !isPinActive && !isBusy,
                  ),
                  Divider(
                    color: theme.colorScheme.onSurface.withAlpha(25),
                    thickness: 1,
                  ),
                  AppTextCard(
                    title: 'COIL B Output Current',
                    currentValue: configState.coilBCurrent > 0
                        ? configState.coilBCurrent
                        : machineData.coilBCurrent,
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(configTabProvider.notifier).setCoilBCurrent(v);
                      }
                    },
                    icon: Icons.settings_input_component,
                    enabled: !isPinActive && !isBusy,
                  ),
                ],
                const SizedBox(height: 16),

                // ── Save button ─────────────────────────────────────────────
                ElevatedButton(
                  onPressed:
                      (isDirty && !isPinActive && !isBusy && !_isSynchronizing)
                      ? _save
                      : null,
                  child: Text(
                    _isSynchronizing ? 'Synchronizing...' : 'Save Config',
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
}
