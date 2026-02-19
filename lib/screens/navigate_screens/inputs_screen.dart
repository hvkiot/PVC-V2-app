import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/configuration_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/providers/processing_overlay_provider.dart';
import 'package:pvc_v2/widgets/app_selector_card.dart';

class InputScreen extends ConsumerStatefulWidget {
  const InputScreen({super.key});

  @override
  ConsumerState<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends ConsumerState<InputScreen> {
  bool _isSynchronizing = false;

  @override
  void initState() {
    super.initState();
  }

  void save() async {
    final machineData = ref.read(machineDataProvider);
    final inputsState = ref.read(inputsTabProvider);
    final bleNotifier = ref.read(bleProvider.notifier);
    final overlayNotifier = ref.read(processingOverlayProvider.notifier);
    final messageNotifier = ref.read(globalMessageProvider.notifier);

    // Resolve display values (same logic as build)
    final selectedMode = inputsState.selectedMode ?? machineData.func;
    final input1 =
        inputsState.selectedInput1 ??
        (machineData.mode == 'V' ? 'Voltage' : 'Current');
    final input2 =
        inputsState.selectedInput2 ??
        (machineData.mode == 'V' ? 'Voltage' : 'Current');

    // 1. Safety Validation: Pin 15 must be OFF
    if (machineData.pin15) {
      messageNotifier.showError(
        "PIN 15 Logic Conflict — Disable Pin 15 to modify settings",
      );
      return;
    }

    overlayNotifier.state = true;
    setState(() => _isSynchronizing = true);

    // 2. Identify changed data
    List<String> commandsToSend = [];

    bool modeChanged = selectedMode != machineData.func;
    if (modeChanged) {
      commandsToSend.add(selectedMode);
    }

    String requestedInputHW = input1.toUpperCase();
    String currentInputHW = machineData.mode == 'V' ? 'VOLTAGE' : 'CURRENT';
    if (modeChanged || requestedInputHW != currentInputHW) {
      commandsToSend.add(requestedInputHW);
    }

    if (selectedMode == '196') {
      String requestedInput2HW = input2.toUpperCase();
      if (requestedInput2HW != requestedInputHW) {
        commandsToSend.add(requestedInput2HW);
      }
    }

    if (commandsToSend.isEmpty) {
      overlayNotifier.state = false;
      messageNotifier.showSuccess("No changes detected.");
      return;
    }

    // 3. Sequential send with hardware delays (1500ms for input mode changes)
    bool allSuccess = true;
    for (String command in commandsToSend) {
      bool success = await bleNotifier.writeToCharacteristic(command);
      if (!success) {
        allSuccess = false;
        break;
      }
      await Future.delayed(const Duration(seconds: 4));
    }

    overlayNotifier.state = false;
    setState(() => _isSynchronizing = false);

    if (allSuccess) {
      // State Restoration: clear local overrides, force re-read from hardware
      ref.read(inputsTabProvider.notifier).reset();
      messageNotifier.showSuccess("Input configuration written successfully");
    } else {
      messageNotifier.showError("Write failed — transaction aborted");
    }
  }

  @override
  Widget build(BuildContext context) {
    final machineData = ref.watch(machineDataProvider);
    final inputsState = ref.watch(inputsTabProvider);
    final inputsNotifier = ref.read(inputsTabProvider.notifier);
    final theme = Theme.of(context);

    final bool isPin15Active = machineData.pin15;

    // Resolve display values: User Selection OR Hardware Value
    final displayMode = inputsState.selectedMode ?? machineData.func;
    final displayInput1 =
        inputsState.selectedInput1 ??
        (machineData.mode == 'V' ? 'Voltage' : 'Current');
    final displayInput2 =
        inputsState.selectedInput2 ??
        (machineData.mode == 'V' ? 'Voltage' : 'Current');

    // Dirty Check: enable Save only when local selections differ from hardware
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (isPin15Active)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  "Device is currently enabled. Disable Pin 15 to modify EEPROM settings",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            AppSelectorCard(
              title: 'Mode',
              currentValue: displayMode,
              options: ['195', '196'],
              onChanged: (value) => inputsNotifier.setMode(value!),
              icon: Icons.mode,
              enabled: !isPin15Active,
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
                enabled: !isPin15Active,
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
                enabled: !isPin15Active,
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
                enabled: !isPin15Active,
              ),
            ],
            Spacer(),
            ElevatedButton(
              onPressed: (isDirty && !isPin15Active && !_isSynchronizing)
                  ? () => save()
                  : null,
              child: Text(_isSynchronizing ? 'Synchronizing...' : 'Save'),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
