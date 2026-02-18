import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/configuration_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/providers/processing_overlay_provider.dart';
import 'package:pvc_v2/theme/app_colors.dart';
import 'package:pvc_v2/widgets/app_text_card.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  bool _isSynchronizing = false;

  @override
  void initState() {
    super.initState();
    // Sync local state with hardware current values mainly on first load
    // or we can leave it to the user.
    // Better UX: Pre-fill with current hardware values.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final machineData = ref.read(machineDataProvider);
      final configNotifier = ref.read(configTabProvider.notifier);
      // We overwrite on init to ensure we start fresh?
      // "prevents data loss when switching tabs" -> means we SHOULD NOT overwrite if we have edits.
      // But how do we know if we have edits?
      // We can check if the provider values are "0.0".
      // Or we can just let the provider hold the state.
      // Let's assume on *app* start it's 0.0.
      // For this task, I will sync ONLY IF the current state is the default '0.0'.
      final currentState = ref.read(configTabProvider);

      if (currentState.coilCurrent == '0.0' &&
          currentState.coilACurrent == '0.0' &&
          currentState.coilBCurrent == '0.0') {
        configNotifier.reset(
          machineData.coilCurrent,
          machineData.coilACurrent,
          machineData.coilBCurrent,
        );
      }
    });
  }

  void saveConfig() async {
    final machineData = ref.read(machineDataProvider);
    final configState = ref.read(configTabProvider);
    final bleNotifier = ref.read(bleProvider.notifier);
    final configNotifier = ref.read(configTabProvider.notifier);
    final overlayNotifer = ref.read(processingOverlayProvider.notifier);
    final messageNotifier = ref.read(globalMessageProvider.notifier);

    final String mode = machineData.func;

    // 1. Safety Validation: Pin 15 check
    if (machineData.pin15) {
      messageNotifier.showError("PIN 15 is Active - Disable to edit");
      return;
    }

    // 2. Context-Aware & Range Validation
    bool isInputValid = false;

    // Helper to validate string
    bool isValid(String val) {
      final d = double.tryParse(val);
      if (d == null) return false;
      final i = d.round();
      return i >= 500 && i <= 2600;
    }

    if (mode == '195') {
      isInputValid = isValid(configState.coilCurrent);
      if (!isInputValid) {
        messageNotifier.showError(
          "Input value out of operational range (500mA - 2600mA)",
        );
        return;
      }
    } else {
      // Mode 196
      if (!isValid(configState.coilACurrent) ||
          !isValid(configState.coilBCurrent)) {
        messageNotifier.showError(
          "Input value out of operational range (500mA - 2600mA)",
        );
        return;
      }
    }

    // Start Loading
    overlayNotifer.state = true;
    setState(() => _isSynchronizing = true);

    // 3. Command Preparation
    List<String> commandsToSend = [];
    if (mode == '195') {
      if (configState.coilCurrent != machineData.coilCurrent) {
        commandsToSend.add(
          "CUR:${double.parse(configState.coilCurrent).round()}:195",
        );
      }
    } else {
      if (configState.coilACurrent != machineData.coilACurrent) {
        commandsToSend.add(
          "CURA:${double.parse(configState.coilACurrent).round()}:196",
        );
      }
      if (configState.coilBCurrent != machineData.coilBCurrent) {
        commandsToSend.add(
          "CURB:${double.parse(configState.coilBCurrent).round()}:196",
        );
      }
    }

    if (commandsToSend.isEmpty) {
      overlayNotifer.state = false;
      messageNotifier.showSuccess("No changes detected.");
      return;
    }

    // 4. Sequential Send
    bool allSuccess = true;
    for (int i = 0; i < commandsToSend.length; i++) {
      bool success = await bleNotifier.writeToCharacteristic(commandsToSend[i]);

      if (!success) {
        allSuccess = false;
        break;
      }

      // Hardware delay
      await Future.delayed(const Duration(milliseconds: 3500));
    }

    overlayNotifer.state = false;
    setState(() => _isSynchronizing = false);

    if (allSuccess) {
      // State Restoration: clear local overrides, force re-read from hardware
      configNotifier.reset(
        machineData.coilCurrent,
        machineData.coilACurrent,
        machineData.coilBCurrent,
      );
      messageNotifier.showSuccess("Configuration written to EEPROM");
    } else {
      messageNotifier.showError("EEPROM write failed — transaction aborted");
    }
  }

  @override
  Widget build(BuildContext context) {
    final machineData = ref.watch(machineDataProvider);
    final configState = ref.watch(configTabProvider);
    final configNotifier = ref.read(configTabProvider.notifier);
    final theme = Theme.of(context);

    final String mode = machineData.func;
    final bool isPin15Active = machineData.pin15;

    // Dirty Check Logic
    bool isDirty = false;
    if (mode == '195') {
      isDirty = configState.coilCurrent != machineData.coilCurrent;
    } else {
      isDirty =
          (configState.coilACurrent != machineData.coilACurrent) ||
          (configState.coilBCurrent != machineData.coilBCurrent);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Mode Indicator
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'CURRENT MODE: $mode',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (isPin15Active) ...[
                      const SizedBox(width: 10),
                      Text(
                        '(LOCKED)',
                        style: TextStyle(
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isPin15Active)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Text(
                  "Device is currently enabled. Disable Pin 15 to modify EEPROM settings",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.brandRed,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            if (mode == '195') ...[
              AppTextCard(
                title: 'COIL Output Current',
                currentValue: configState.coilCurrent,
                onChanged: (value) => {
                  if (value != null) configNotifier.setCoilCurrent(value),
                },
                icon: Icons.settings_input_component,
                enabled: !isPin15Active,
              ),
            ] else ...[
              AppTextCard(
                title: 'COIL A Output Current',
                currentValue: configState.coilACurrent,
                onChanged: (value) => {
                  if (value != null) configNotifier.setCoilACurrent(value),
                },
                icon: Icons.settings_input_component,
                enabled: !isPin15Active,
              ),
              Divider(
                color: theme.colorScheme.onSurface.withAlpha(25),
                thickness: 1,
              ),
              AppTextCard(
                title: 'COIL B Output Current',
                currentValue: configState.coilBCurrent,
                onChanged: (value) => {
                  if (value != null) configNotifier.setCoilBCurrent(value),
                },
                icon: Icons.settings_input_component,
                enabled: !isPin15Active,
              ),
            ],
            Spacer(),
            ElevatedButton(
              onPressed: (isDirty && !isPin15Active && !_isSynchronizing)
                  ? () => saveConfig()
                  : null,
              child: Text(
                _isSynchronizing ? 'Synchronizing...' : 'Save Config',
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
