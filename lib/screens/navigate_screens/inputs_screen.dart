import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/models/machine_data.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/theme/app_colors.dart';
import 'package:pvc_v2/widgets/app_selector_card.dart';

class InputScreen extends ConsumerStatefulWidget {
  const InputScreen({super.key});

  @override
  ConsumerState<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends ConsumerState<InputScreen> {
  late final MachineData machineData;
  late final BleState bleState;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  String? _selectedMode;
  String? _selectedInput1;
  String? _selectedInput2;

  @override
  void initState() {
    super.initState();
    machineData = ref.read(machineDataProvider);
    bleState = ref.read(bleProvider);
  }

  bool isLoading = false;

  void modeChanged(String value) {
    setState(() {
      _selectedMode = value;
    });
  }

  void input1Changed(String value) {
    setState(() {
      _selectedInput1 = value;
    });
  }

  void input2Changed(String value) {
    setState(() {
      _selectedInput2 = value;
    });
  }

  void save(
    WidgetRef ref,
    String selectedMode,
    String input1,
    String input2,
  ) async {
    // 1. Get current hardware data from your Provider
    final machineData = ref.read(machineDataProvider); //
    final bleNotifier = ref.read(bleProvider.notifier); //

    // 2. Validation: Pin 15 must be false (OFF) as per W.E.ST. rules
    if (machineData.pin15) {
      //
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ PIN 15 is ON - cannot change function"),
          backgroundColor: isDark ? AppColors.brandRed : Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    // 3. Identify ONLY unique/changed data
    List<String> commandsToSend = [];

    // Check Mode (FUNC)
    bool modeChanged = selectedMode != machineData.func;
    if (modeChanged) {
      commandsToSend.add(selectedMode);
    }

    // Check Input 1 (mapping 'Voltage'/'Current' to hardware codes if necessary)
    // Assuming machineData.mode reflects the current input type
    String requestedInputHW = input1.toUpperCase(); // "VOLTAGE" or "CURRENT"
    String currentInputHW = machineData.mode == 'V' ? 'VOLTAGE' : 'CURRENT';
    if (modeChanged || requestedInputHW != currentInputHW) {
      commandsToSend.add(requestedInputHW);
    }

    // Check Input 2 (only for Mode 196)
    if (selectedMode == '196') {
      String requestedInput2HW = input2.toUpperCase();
      // If Input 2 is different from what was just set for Input 1
      if (requestedInput2HW != requestedInputHW) {
        commandsToSend.add(requestedInput2HW);
      }
    }

    // Check if commandsToSend is empty
    if (commandsToSend.isEmpty) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No changes detected.")));
      return;
    }

    // 4. Execution: Send only the unique commands
    bool allSuccess = true;

    for (String command in commandsToSend) {
      bool success = await bleNotifier.writeToCharacteristic(command); //
      if (!success) allSuccess = false;
      // Small delay to allow the hardware's background thread to process
      await Future.delayed(const Duration(milliseconds: 3500));
    }

    // 5. Result Feedback
    if (allSuccess) {
      setState(() {
        _selectedMode = null;
        _selectedInput1 = null;
        _selectedInput2 = null;
        isLoading = false;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        // Reduced from 4s for better UX
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Updated: ${commandsToSend.join(', ')} successfully",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
              backgroundColor: isDark
                  ? Colors.greenAccent
                  : AppColors.brandCyan,
            ),
          );
        }
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final machineData = ref.watch(machineDataProvider);

    // Resolve which value to show: User Selection OR Hardware Value
    final displayMode = _selectedMode ?? machineData.func;
    final displayInput1 =
        _selectedInput1 ?? (machineData.mode == 'V' ? 'Voltage' : 'Current');
    final displayInput2 =
        _selectedInput2 ?? (machineData.mode == 'V' ? 'Voltage' : 'Current');
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            AppSelectorCard(
              title: 'Mode ',
              currentValue: displayMode,
              options: ['195', '196'],
              onChanged: (value) => modeChanged(value!),
              icon: Icons.mode,
            ),
            Divider(color: AppColors.darkTextSecondary, thickness: 1),
            if (displayMode == '195') ...[
              AppSelectorCard(
                title: 'Input',
                currentValue: displayInput1,
                options: ['Voltage', 'Current'],
                onChanged: (value) => input1Changed(value!),
                icon: Icons.input,
              ),
              Divider(color: AppColors.darkTextSecondary, thickness: 1),
            ] else ...[
              AppSelectorCard(
                title: 'Input 1',
                currentValue: displayInput1,
                options: ['Voltage', 'Current'],
                onChanged: (value) => input1Changed(value!),
                icon: Icons.input,
              ),
              Divider(color: AppColors.darkTextSecondary, thickness: 1),
              AppSelectorCard(
                title: 'Input 2',
                currentValue: displayInput2,
                options: ['Voltage', 'Current'],
                onChanged: (value) => input2Changed(value!),
                icon: Icons.input,
              ),
            ],
            Spacer(),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () => save(ref, displayMode, displayInput1, displayInput2),
              child: Text(isLoading ? 'Saving...' : 'Save'),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
