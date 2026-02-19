import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/theme/app_colors.dart';
import 'package:pvc_v2/utils/unit_converter.dart';

class PamDataScreen extends ConsumerStatefulWidget {
  final BluetoothDevice device;
  const PamDataScreen({super.key, required this.device});

  @override
  ConsumerState<PamDataScreen> createState() => _PamDataScreenState();
}

class _PamDataScreenState extends ConsumerState<PamDataScreen> {
  final List<BluetoothDevice> validDevices = [];

  bool isScanning = false;

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final bleState = ref.watch(bleProvider);
    final bleNotifier = ref.read(bleProvider.notifier);
    final machineData = ref.watch(machineDataProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isConnected = bleState.connectedDevice == device;
    final isDataAvailable = bleState.characteristicValue.isNotEmpty;
    final isConnecting = bleState.isConnecting;
    String unit(String mode) {
      if (mode == 'C') {
        return 'mA';
      } else {
        return 'V';
      }
    }

    final List<Map<String, String>> sensorData = [
      {
        'title': 'INPUT A',
        'value': UnitConverter.format(machineData.inputA),
        'unit': unit(machineData.mode),
      },
      {
        'title': 'COIL A',
        'value': UnitConverter.format(machineData.coilA),
        'unit': 'mA',
      },
      {
        'title': 'INPUT B',
        'value': UnitConverter.format(machineData.inputB),
        'unit': unit(machineData.mode),
      },
      {
        'title': 'COIL B',
        'value': UnitConverter.format(machineData.coilB),
        'unit': 'mA',
      },
    ];

    bool led(String ready, bool pin15, bool pin6) {
      if (ready == "ALL OFF") {
        return false;
      }

      if (pin15 && pin6) {
        return ready == "A + B ACTIVE";
      }

      if (ready == "A ACTIVE" || ready == "B ACTIVE") {
        return true;
      }

      return false;
    }

    bool ledStandard(String ready) {
      if (ready == "A + B ACTIVE") {
        return true;
      }
      return false;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        if (!isConnected) ...[
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 1. Visual Status Indicator
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bluetooth_disabled_rounded,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. Primary Status Message
                    Text(
                      "HARDWARE DISCONNECTED",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 3. Instruction Text
                    Text(
                      "The connection to the PVC controller was lost. Please ensure the device is powered on and within range.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 4. Action Button (Professional CTA)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => isConnecting
                            ? null
                            : bleNotifier.connectToDevice(device),
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 20,
                          color: isConnecting
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.primary,
                        ),
                        label: Text(
                          isConnecting
                              ? "CONNECTING..."
                              : "RECONNECT TO THE DEVICE",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isConnecting
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.primary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: isConnecting
                              ? BorderSide(
                                  color: theme.colorScheme.onSurfaceVariant,
                                )
                              : BorderSide(color: theme.colorScheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Device ID: ${device.platformName.replaceAll('PVC-', '')}',
                style: theme.textTheme.titleLarge,
              ),
              if (isConnected)
                IconButton(
                  icon: isDataAvailable
                      ? Icon(Icons.bluetooth_connected)
                      : Icon(Icons.bluetooth),
                  color: isDataAvailable
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  onPressed: () {
                    bleNotifier.connectToDevice(device);
                  },
                ),
            ],
          ),

          Expanded(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.8,
              ),
              padding: const EdgeInsets.all(16),
              itemCount: sensorData.length + 2,
              itemBuilder: (context, index) {
                if (index == 4) {
                  return _buildLEDCard(
                    'MODE 195',
                    machineData.func == '195', // Pass a boolean for "active"
                    context,
                    isDark,
                  );
                }
                if (index == 5) {
                  return _buildLEDCard(
                    'MODE 196',
                    machineData.func == '196',
                    context,
                    isDark,
                  );
                }
                return _buildCard(sensorData[index], context);
              },
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: _buildLEDCard(
                      "READY ${machineData.ready}",
                      machineData.enableB
                          ? led(
                              machineData.ready,
                              machineData.pin15,
                              machineData.pin6,
                            )
                          : ledStandard(machineData.ready),
                      context,
                      isDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Supply Voltage: 24V",
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 10),
                  _buildTextRow(
                    "ENABLE (A): PIN 15",
                    machineData.pin15,
                    isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildTextRow("ENABLE (B): PIN 6", machineData.pin6, isDark),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCard(Map<String, String> data, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      // The theme now handles the background color and shape automatically
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['title']!.toUpperCase(),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  data['value']!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    data['unit']!,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLEDCard(
    String title,
    bool isActive,
    BuildContext context,
    bool isDark,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    // Use Brand Cyan for the glow if active, otherwise a muted grey
    final ledColor = isActive
        ? isDark
              ? AppColors.brandCyan
              : AppColors.brandRed
        : Theme.of(context).disabledColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ledColor,
                  boxShadow: [
                    if (isActive)
                      BoxShadow(
                        color: ledColor.withValues(alpha: 0.6),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                  ],
                  gradient: isActive
                      ? RadialGradient(
                          colors: [
                            Colors.white,
                            ledColor,
                            ledColor.withValues(alpha: 0.8),
                          ],
                          stops: const [0.1, 0.5, 1.0],
                        )
                      : null,
                ),
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                isActive ? "ACTIVE" : "INACTIVE",
                style: TextStyle(
                  color: ledColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextRow(String title, bool value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 24),
          ),

          Icon(
            value ? Icons.check_box : Icons.check_box_outline_blank,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
