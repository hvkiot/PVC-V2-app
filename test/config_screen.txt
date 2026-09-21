import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/configuration_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/providers/processing_overlay_provider.dart';
import 'package:pvc_v2/utils/machine_utils.dart';
import 'package:pvc_v2/utils/responsive_helper.dart';
import 'package:pvc_v2/widgets/app_text_card.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  bool _isSynchronizing = false;

  // TRANSITION=True arrives on the first BLE notify tick after the firmware
  // calls setTransition(true), so the ack wait is near-immediate.
  static const Duration ackTimeout = Duration(seconds: 3);
  // TRANSITION=True -> False completion backstop for parameter/current writes
  // (AINA/AINB + SAVE + 1.5s EEPROM ~= 3s). The 50ms poll exits the instant
  // False arrives; this bound only guards stale hardware.
  static const Duration doneTimeout = Duration(seconds: 4);

  /// Same transition wait used by inputs_screen — see that file for the flow.
  Future<bool> _waitForTransition() async {
    final ackStart = DateTime.now();
    bool seenTrue = false;
    while (DateTime.now().difference(ackStart) < ackTimeout) {
      if (ref.read(machineDataProvider).transition) {
        seenTrue = true;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (seenTrue) return _waitForDone();
    if (!ref.read(machineDataProvider).transition) return true;
    return _waitForDone();
  }

  Future<bool> _waitForDone() async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < doneTimeout) {
      if (!ref.read(machineDataProvider).transition) return true;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  void _saveConfig() async {
    final machineData = ref.read(machineDataProvider);
    final configState = ref.read(configTabProvider);
    final bleNotifier = ref.read(bleProvider.notifier);
    final configNotifier = ref.read(configTabProvider.notifier);
    final messageNotifier = ref.read(globalMessageProvider.notifier);
    final overlayNotifier = ref.read(processingOverlayProvider.notifier);

    final String mode = machineData.func;

    if (machineData.transition) {
      messageNotifier.showError("Device is busy, please wait");
      return;
    }

    bool isValid(double val) => val.round() >= 500 && val.round() <= 2600;

    // Validate only the values that have been actively edited (> 0)
    if (mode == '195') {
      final checkVal = configState.coilCurrent > 0
          ? configState.coilCurrent
          : machineData.coilCurrent;
      if (!isValid(checkVal)) {
        messageNotifier.showError("Enter a value between 500 and 2600");
        return;
      }
    } else {
      final checkA = configState.coilACurrent > 0
          ? configState.coilACurrent
          : machineData.coilACurrent;
      final checkB = configState.coilBCurrent > 0
          ? configState.coilBCurrent
          : machineData.coilBCurrent;
      if (!isValid(checkA) || !isValid(checkB)) {
        messageNotifier.showError("Enter a value between 500 and 2600");
        return;
      }
    }

    overlayNotifier.state = true;
    setState(() => _isSynchronizing = true);

    List<String> commandsToSend = [];
    if (mode == '195') {
      if (configState.coilCurrent > 0 &&
          configState.coilCurrent.round() != machineData.coilCurrent.round()) {
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

    if (commandsToSend.isEmpty) {
      overlayNotifier.state = false;
      setState(() => _isSynchronizing = false);
      messageNotifier.showSuccess("Nothing to save");
      return;
    }

    bool allSuccess = true;
    for (String cmd in commandsToSend) {
      bool success = await bleNotifier.writeToCharacteristic(cmd);
      if (!success) {
        allSuccess = false;
        break;
      }
      // Wait for the TRANSITION=True -> False cycle before the next command
      // (keep one-command-at-a-time until Phase 3 proves batching is safe).
      final completed = await _waitForTransition();
      if (!completed) {
        allSuccess = false;
        bleNotifier.setBusy(false);
        break;
      }
    }

    overlayNotifier.state = false;
    setState(() => _isSynchronizing = false);

    if (allSuccess) {
      configNotifier.reset(0.0, 0.0, 0.0);
      messageNotifier.showSuccess("Settings updated successfully");
    } else {
      messageNotifier.showError("Failed to save settings");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. DYNAMIC MODE LISTENER
    ref.listen<String>(machineDataProvider.select((d) => d.func), (prev, next) {
      if (prev != null && prev != next) {
        // Mode changed! Wipe the UI drafts entirely so no old values leak into the new mode.
        ref.read(configTabProvider.notifier).reset(0.0, 0.0, 0.0);
      }
    });

    final machineData = ref.watch(machineDataProvider);
    final configState = ref.watch(configTabProvider);
    final configNotifier = ref.read(configTabProvider.notifier);
    final theme = Theme.of(context);

    final String mode = machineData.func;
    final bool isPinActive = machineData.pin15 || machineData.pin6;
    final bool isBusy = ref.watch(bleProvider).isBusy;

    // 2. BULLETPROOF DISPLAY RESOLUTION
    // If the UI draft is 0, fall back to Machine Truth. If > 0, show User's Draft.
    final double displayA = configState.coilACurrent > 0
        ? configState.coilACurrent
        : machineData.coilACurrent;
    final double displayB = configState.coilBCurrent > 0
        ? configState.coilBCurrent
        : machineData.coilBCurrent;
    final double displayMain = configState.coilCurrent > 0
        ? configState.coilCurrent
        : machineData.coilCurrent;

    // 4. Robust Dirty Check

    bool isDirty = false;

    if (mode == '195') {
      isDirty = displayMain.round() != machineData.coilCurrent.round();
    } else {
      isDirty =
          (displayA.round() != machineData.coilACurrent.round()) ||
          (displayB.round() != machineData.coilBCurrent.round());
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ResponsiveWrapper(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
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
                if (mode == '195') ...[
                  AppTextCard(
                    title: 'COIL Output Current',
                    currentValue: displayMain,
                    onChanged: (value) {
                      if (value != null) {
                        configNotifier.setCoilCurrent(value);
                      }
                    },
                    icon: Icons.settings_input_component,
                    enabled: !isPinActive && !isBusy,
                  ),
                ] else ...[
                  AppTextCard(
                    title: 'COIL A Output Current',
                    currentValue: displayA,
                    onChanged: (value) {
                      if (value != null) {
                        configNotifier.setCoilACurrent(value);
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
                    currentValue: displayB,
                    onChanged: (value) {
                      if (value != null) {
                        configNotifier.setCoilBCurrent(value);
                      }
                    },
                    icon: Icons.settings_input_component,
                    enabled: !isPinActive && !isBusy,
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed:
                      (isDirty && !isPinActive && !isBusy && !_isSynchronizing)
                      ? _saveConfig
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
