import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/models/machine_data.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/theme/app_colors.dart';
import 'package:pvc_v2/widgets/app_text_card.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  late final MachineData machineData;
  late final BleState bleState;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    machineData = ref.read(machineDataProvider);
    bleState = ref.read(bleProvider);
  }

  late String coilACurrent = machineData.coilACurrent;
  late String coilBCurrent = machineData.coilBCurrent;
  late String coilCurrent = machineData.coilCurrent;

  void saveConfig(
    WidgetRef ref,
    String coilACurrent,
    String coilBCurrent,
  ) async {
    final machineData = ref.read(machineDataProvider);
    final bleNotifier = ref.read(bleProvider.notifier);
    final String mode = machineData.func;

    // 1. Safety Validation: Pin 15 check
    if (machineData.pin15) {
      _showErrorSnackBar("PIN 15 is ON - cannot change configuration");
      return;
    }

    // 2. Context-Aware & Range Validation
    bool isInputValid = false;
    if (mode == '195') {
      isInputValid =
          double.tryParse(coilCurrent) != null && _isWithinRange(coilCurrent);
    } else {
      isInputValid =
          double.tryParse(coilACurrent) != null &&
          double.tryParse(coilBCurrent) != null &&
          _isWithinRange(coilACurrent) &&
          _isWithinRange(coilBCurrent);
    }

    if (!isInputValid) return; // Errors handled by helper methods

    setState(() => isLoading = true);

    // 3. Command Preparation (Using the :VALUE:MODE format)
    List<String> commandsToSend = [];
    if (mode == '195') {
      if (coilCurrent != machineData.coilCurrent) {
        commandsToSend.add("CUR:${double.parse(coilCurrent).round()}:195");
      }
    } else {
      if (coilACurrent != machineData.coilACurrent) {
        commandsToSend.add("CURA:${double.parse(coilACurrent).round()}:196");
      }
      if (coilBCurrent != machineData.coilBCurrent) {
        commandsToSend.add("CURB:${double.parse(coilBCurrent).round()}:196");
      }
    }

    if (commandsToSend.isEmpty) {
      setState(() => isLoading = false);
      _showSuccessSnackBar("No changes detected.");
      return;
    }

    // 4. Sequential Send with Hardware-Synced Delays
    bool allSuccess = true;
    for (int i = 0; i < commandsToSend.length; i++) {
      bool success = await bleNotifier.writeToCharacteristic(commandsToSend[i]);

      if (!success) {
        allSuccess = false;
        break; // Stop execution on hardware failure
      }

      // UX IMPROVEMENT: Hardware needs 3s for EEPROM write + 0.5s safety margin
      // Only delay if there are more commands to send or to show "Success" state
      await Future.delayed(const Duration(milliseconds: 3500));
    }

    // 5. Final Result Feedback
    if (mounted) {
      setState(() => isLoading = false);
      if (allSuccess) {
        _showSuccessSnackBar("✅ Configuration Saved & Verified Successfully");
      }
    }
  }

  // Helper methods to keep code clean
  bool _isWithinRange(String value) {
    final val = double.tryParse(value)?.round() ?? 0;
    if (val < 500 || val > 2600) {
      _showErrorSnackBar("Value $val out of range (500-2600)");
      return false;
    }
    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isDark ? AppColors.brandCyan : Colors.green,
      ),
    );
  }

  void validateInput(String value) {
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Input value is empty"),
          backgroundColor: isDark ? AppColors.brandRed : Colors.redAccent,
        ),
      );
      return;
    }
    // Parse as double first to handle "1000.0"
    final doubleValue = double.tryParse(value);

    if (doubleValue == null) {
      // Handle case where input isn't a number at all
      return;
    }

    // Convert to int for your range check
    final int parsedValue = doubleValue.round();

    if (parsedValue < 500 || parsedValue > 2600) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Input value is not in range of 500-2600"),
          backgroundColor: isDark ? AppColors.brandRed : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final machineData = ref.watch(machineDataProvider);
    final String mode = machineData.func;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Current Mode: $mode',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            if (mode == '195') ...[
              AppTextCard(
                title: 'COIL Output Current',
                currentValue: coilCurrent,
                onChanged: (value) => {
                  setState(() {
                    coilCurrent = value!;
                  }),
                },
                icon: Icons.settings_input_component,
              ),
            ] else ...[
              AppTextCard(
                title: 'COIL A Output Current',
                currentValue: coilACurrent,
                onChanged: (value) => {
                  setState(() {
                    coilACurrent = value!;
                  }),
                },
                icon: Icons.settings_input_component,
              ),
              Divider(color: AppColors.darkTextSecondary, thickness: 1),
              AppTextCard(
                title: 'COIL B Output Current',
                currentValue: coilBCurrent,
                onChanged: (value) => {
                  setState(() {
                    coilBCurrent = value!;
                  }),
                },
                icon: Icons.settings_input_component,
              ),
            ],
            Spacer(),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () => saveConfig(ref, coilACurrent, coilBCurrent),
              child: Text(isLoading ? 'Saving...' : 'Save Config'),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
