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

  @override
  void initState() {
    super.initState();
    machineData = ref.read(machineDataProvider);
    bleState = ref.read(bleProvider);
  }

  late String mode = machineData.func;
  late String input1 = machineData.mode == 'V' ? 'Voltage' : 'Current';
  late String input2 = machineData.mode == 'V' ? 'Voltage' : 'Current';
  bool isLoading = false;

  void modeChanged(String value) {
    setState(() {
      mode = value;
    });
  }

  void input1Changed(String value) {
    setState(() {
      input1 = value;
    });
  }

  void input2Changed(String value) {
    setState(() {
      input2 = value;
    });
  }

  void save(
    WidgetRef ref,
    String selectedMode,
    String input1,
    String input2,
  ) async {
    setState(() {
      isLoading = true;
    });

    final machineData = ref.read(machineDataProvider);
    final bleNotifier = ref.read(bleProvider.notifier);

    // 1. Validation: Pin 15 must be false (OFF) to change function
    if (machineData.pin15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ PIN 15 is ON - cannot change function"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 2. BLE Client Sends Command
    // Writes "195" or "196" to UUID 12345678-1234-5678-1234-56789abcdef1
    bool success = await bleNotifier.writeToCharacteristic(selectedMode);
    bool success2 = false;
    bool success3 = false;
    if (mode == '195') {
      success2 = await bleNotifier.writeToCharacteristic(input1);
      success3 = true;
    } else {
      success2 = await bleNotifier.writeToCharacteristic(input1);
      success3 = await bleNotifier.writeToCharacteristic(input2);
    }

    if (success && success2 && success3) {
      Future.delayed(const Duration(seconds: 4), () {
        setState(() {
          isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Command '$selectedMode', '$input1', '$input2' sent successfully",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              backgroundColor: AppColors.brandCyan,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              currentValue: mode,
              options: ['195', '196'],
              onChanged: (value) => modeChanged(value!),
              icon: Icons.mode,
            ),
            Divider(color: AppColors.darkTextSecondary, thickness: 1),
            if (mode == '195') ...[
              AppSelectorCard(
                title: 'Input',
                currentValue: input1,
                options: ['Voltage', 'Current'],
                onChanged: (value) => input1Changed(value!),
                icon: Icons.input,
              ),
              Divider(color: AppColors.darkTextSecondary, thickness: 1),
            ] else ...[
              AppSelectorCard(
                title: 'Input 1',
                currentValue: input1,
                options: ['Voltage', 'Current'],
                onChanged: (value) => input1Changed(value!),
                icon: Icons.input,
              ),
              Divider(color: AppColors.darkTextSecondary, thickness: 1),
              AppSelectorCard(
                title: 'Input 2',
                currentValue: input2,
                options: ['Voltage', 'Current'],
                onChanged: (value) => input2Changed(value!),
                icon: Icons.input,
              ),
            ],
            Spacer(),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () => save(ref, mode, input1, input2),
              child: Text(isLoading ? 'Saving...' : 'Save'),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
