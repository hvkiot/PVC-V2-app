import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/configuration_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/providers/processing_overlay_provider.dart';
import 'package:pvc_v2/utils/responsive_helper.dart';
import 'package:pvc_v2/widgets/app_selector_card.dart';

class InputScreen extends ConsumerStatefulWidget {
  const InputScreen({super.key});

  @override
  ConsumerState<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends ConsumerState<InputScreen> {
  bool _isSynchronizing = false;

  @override
  Widget build(BuildContext context) {
    final machineData = ref.watch(machineDataProvider);
    final inputsState = ref.watch(inputsTabProvider);
    final inputsNotifier = ref.read(inputsTabProvider.notifier);
    final theme = Theme.of(context);

    final bool isPin15Active = machineData.pin15;
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
                if (isPin15Active)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        "Device is currently enabled. Disable Pin 15 to modify EEPROM settings",
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
                  enabled: !isPin15Active && !isBusy,
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
                    enabled: !isPin15Active && !isBusy,
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
                    enabled: !isPin15Active && !isBusy,
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
                    enabled: !isPin15Active && !isBusy,
                  ),
                ],
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed:
                      (isDirty &&
                          !isPin15Active &&
                          !isBusy &&
                          !_isSynchronizing)
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

    // Build atomic command
    final unit = input1.toUpperCase();
    final shortUnit = unit == 'VOLTAGE' ? 'V' : 'C';
    final modeChanged = selectedMode != machineData.func;
    final String command;

    if (modeChanged) {
      command = '$selectedMode:$shortUnit';
    } else {
      command = unit;
    }

    bool writeOk = await bleNotifier.writeToCharacteristic(command);

    if (!writeOk) {
      overlayNotifier.state = false;
      setState(() => _isSynchronizing = false);
      messageNotifier.showError("Failed to send command");
      return;
    }

    // Wait for ESP to acknowledge the command (transition → true)
    final ackDeadline = DateTime.now().add(const Duration(seconds: 3));
    bool acknowledged = false;
    while (DateTime.now().isBefore(ackDeadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (ref.read(machineDataProvider).transition) {
        acknowledged = true;
        break;
      }
    }

    if (!acknowledged) {
      overlayNotifier.state = false;
      setState(() => _isSynchronizing = false);
      bleNotifier.setBusy(false);
      messageNotifier.showError("Device not responding");
      return;
    }

    // Wait for hardware to finish (transition → false)
    final doneDeadline = DateTime.now().add(const Duration(seconds: 10));
    bool completed = false;
    while (DateTime.now().isBefore(doneDeadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!ref.read(machineDataProvider).transition) {
        completed = true;
        break;
      }
    }

    if (completed) {
      overlayNotifier.state = false;
      setState(() => _isSynchronizing = false);
      ref.read(inputsTabProvider.notifier).reset();
      messageNotifier.showSuccess("Settings updated successfully");
    } else {
      overlayNotifier.state = false;
      setState(() => _isSynchronizing = false);
      bleNotifier.setBusy(false);
      messageNotifier.showError("Device update timed out");
    }
  }
}
