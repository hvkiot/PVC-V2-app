import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/configuration_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/providers/processing_overlay_provider.dart';
import 'package:pvc_v2/utils/machine_utils.dart';
import 'package:pvc_v2/utils/responsive_helper.dart';
import 'package:pvc_v2/widgets/app_selector_card.dart';

class InputScreen extends ConsumerStatefulWidget {
  const InputScreen({super.key});

  @override
  ConsumerState<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends ConsumerState<InputScreen> {
  bool _isSynchronizing = false;

  // TRANSITION=True arrives on the first BLE notify tick after the firmware
  // calls setTransition(true), so the ack wait is near-immediate.
  static const Duration ackTimeout = Duration(seconds: 3);
  // Upper bounds on the TRANSITION=True -> False completion window, chosen by
  // *measured* firmware behavior (Phase 2), not assumed:
  //   - Function change (195<->196): PAM reboot + delay(2000) + MODE poll +
  //     1.5s EEPROM save  ~= 7.1s. Use a generous backstop so we never
  //     false-timeout a legitimate slow operation.
  //   - Mode / parameter change: AINA/AINB + SAVE + 1.5s EEPROM  ~= 3s.
  // The responsiveness comes from the 50ms poll (exits the instant False
  // arrives); the timeout is only a stale-hardware backstop.
  static const Duration doneTimeoutFunctionChange = Duration(seconds: 10);
  static const Duration doneTimeoutParameterChange = Duration(seconds: 4);

  /// Waits until hardware signals completion.
  ///
  /// Flow (Phase 1): command sent -> await TRANSITION=True (starts the
  /// completion window) -> await TRANSITION=False -> success.
  ///
  /// [doneTimeout] is the upper bound on the completion window; pass the value
  /// matching the operation (function change vs parameter/mode change).
  ///
  /// Returns true on a clean True->False completion, false on timeout (the
  /// caller falls back to the busy-guard / shows "timed out").
  Future<bool> _waitForTransition(Duration doneTimeout) async {
    final ackStart = DateTime.now();
    bool seenTrue = false;
    while (DateTime.now().difference(ackStart) < ackTimeout) {
      // Re-read the flag each poll — MachineData is an immutable value object.
      final transition = ref.read(machineDataProvider).transition;
      if (transition) {
        seenTrue = true;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (seenTrue) {
      return _waitForDone(doneTimeout);
    }
    // Never saw True within the ack window. The command may still be in
    // flight; give the done window a chance. If it reads False now, complete.
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

  @override
  Widget build(BuildContext context) {
    final machineData = ref.watch(machineDataProvider);
    final inputsState = ref.watch(inputsTabProvider);
    final inputsNotifier = ref.read(inputsTabProvider.notifier);
    final theme = Theme.of(context);

    final bool isPinActive = machineData.pin15 || machineData.pin6;
    final bool isBusy = ref.watch(bleProvider).isBusy;

    final displayMode = inputsState.selectedMode ?? machineData.func;
    final displayInput1 =
        inputsState.selectedInput1 ??
        (machineData.mode == 'V' ? 'Voltage' : 'Current');
    final displayInput2 =
        inputsState.selectedInput2 ??
        (machineData.mode == 'V' ? 'Voltage' : 'Current');

    bool isDirty = false;
    if (inputsState.selectedMode != null &&
        inputsState.selectedMode != machineData.func) {
      isDirty = true;
    }
    if (inputsState.selectedInput1 != null) {
      final currentInput1 = machineData.mode == 'V' ? 'Voltage' : 'Current';
      if (inputsState.selectedInput1 != currentInput1) isDirty = true;
    }
    if (inputsState.selectedInput2 != null) {
      final currentInput2 = machineData.mode == 'V' ? 'Voltage' : 'Current';
      if (inputsState.selectedInput2 != currentInput2) isDirty = true;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ResponsiveWrapper(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (isPinActive)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        "Device is currently enabled. Disable ${activePinsLabel(machineData.pin15, machineData.pin6)} to modify EEPROM settings",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                AppSelectorCard(
                  title: 'Mode',
                  currentValue: displayMode,
                  options: ['195', '196'],
                  onChanged: (value) => inputsNotifier.setMode(value!),
                  icon: Icons.mode,
                  enabled: !isPinActive && !isBusy,
                ),
                Divider(
                  color: theme.colorScheme.onSurface.withAlpha(25),
                  thickness: 1,
                ),
                if (displayMode == '195') ...[
                  AppSelectorCard(
                    title: 'Input',
                    currentValue: displayInput1,
                    options: ['Voltage', 'Current'],
                    onChanged: (value) => inputsNotifier.setInput1(value!),
                    icon: Icons.input,
                    enabled: !isPinActive && !isBusy,
                  ),
                  Divider(
                    color: theme.colorScheme.onSurface.withAlpha(25),
                    thickness: 1,
                  ),
                ] else ...[
                  AppSelectorCard(
                    title: 'Input 1',
                    currentValue: displayInput1,
                    options: ['Voltage', 'Current'],
                    onChanged: (value) => inputsNotifier.setInput1(value!),
                    icon: Icons.input,
                    enabled: !isPinActive && !isBusy,
                  ),
                  Divider(
                    color: theme.colorScheme.onSurface.withAlpha(25),
                    thickness: 1,
                  ),
                  AppSelectorCard(
                    title: 'Input 2',
                    currentValue: displayInput2,
                    options: ['Voltage', 'Current'],
                    onChanged: (value) => inputsNotifier.setInput2(value!),
                    icon: Icons.input,
                    enabled: !isPinActive && !isBusy,
                  ),
                ],
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed:
                      (isDirty && !isPinActive && !isBusy && !_isSynchronizing)
                      ? () {
                          save();
                        }
                      : null,
                  child: Text(_isSynchronizing ? 'Synchronizing...' : 'Save'),
                ),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void save() async {
    final machineData = ref.read(machineDataProvider);
    final inputsState = ref.read(inputsTabProvider);
    final bleNotifier = ref.read(bleProvider.notifier);
    final overlayNotifier = ref.read(processingOverlayProvider.notifier);
    final messageNotifier = ref.read(globalMessageProvider.notifier);

    final selectedMode = inputsState.selectedMode ?? machineData.func;
    final input1 =
        inputsState.selectedInput1 ??
        (machineData.mode == 'V' ? 'Voltage' : 'Current');
    final input2 =
        inputsState.selectedInput2 ??
        (machineData.mode == 'V' ? 'Voltage' : 'Current');

    if (selectedMode == '196' && input1.toUpperCase() != input2.toUpperCase()) {
      messageNotifier.showError("Both inputs must match in Mode 196");
      return;
    }

    overlayNotifier.state = true;
    setState(() => _isSynchronizing = true);

    final unit = input1.toUpperCase();
    final shortUnit = unit == 'VOLTAGE' ? 'V' : 'C';
    final modeChanged = selectedMode != machineData.func;

    // ---------- SINGLE COMBINED PROTOCOL ----------
    String command;
    if (modeChanged) {
      command = '$selectedMode:$shortUnit'; // e.g., "196:V"
    } else {
      command = unit; // e.g., "Voltage"
    }

    bool writeOk = await bleNotifier.writeToCharacteristic(command);
    if (!writeOk) {
      overlayNotifier.state = false;
      setState(() => _isSynchronizing = false);
      messageNotifier.showError("Failed to send command");
      return;
    }

    // Wait for the hardware transition to complete.
    // Phase 1: await TRANSITION=True, then TRANSITION=False.
    // Function changes (195<->196) legitimately take ~7s (PAM reboot + save),
    // so use the longer backstop; unit/mode changes ~3s.
    final doneTimeout = modeChanged
        ? doneTimeoutFunctionChange
        : doneTimeoutParameterChange;
    final completed = await _waitForTransition(doneTimeout);
    if (!completed) {
      overlayNotifier.state = false;
      setState(() => _isSynchronizing = false);
      bleNotifier.setBusy(false);
      messageNotifier.showError("Device update timed out");
      return;
    }

    // ---------- Handle final result ----------
    overlayNotifier.state = false;
    setState(() => _isSynchronizing = false);
    ref.read(inputsTabProvider.notifier).reset();
    messageNotifier.showSuccess("Settings updated successfully");
  }
}
