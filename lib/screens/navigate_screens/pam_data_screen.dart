import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/theme/app_colors.dart';
import 'package:pvc_v2/utils/responsive_helper.dart';
import 'package:pvc_v2/utils/unit_converter.dart';

class PamDataScreen extends ConsumerStatefulWidget {
  final BluetoothDevice device;
  const PamDataScreen({super.key, required this.device});

  @override
  ConsumerState<PamDataScreen> createState() => _PamDataScreenState();
}

class _PamDataScreenState extends ConsumerState<PamDataScreen> {
  // Debounce timer to prevent excessive rebuilds
  Timer? _updateTimer;

  @override
  void dispose() {
    _connSub?.cancel();
    _updateTimer?.cancel();
    _hasNavigatedBack = true;
    super.dispose();
  }

  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _hasNavigatedBack = false;

  @override
  void initState() {
    super.initState();
    // Listen to connection state changes on the device directly
    _connSub = widget.device.connectionState.listen((state) {
      if (!mounted) return;
      if (state == BluetoothConnectionState.disconnected &&
          !_hasNavigatedBack) {
        _navigateBackToScan();
      }
    });
  }

  void _navigateBackToScan() {
    if (_hasNavigatedBack) return;
    _hasNavigatedBack = true;

    // Show a message to the user
    if (mounted) {
      ref
          .read(globalMessageProvider.notifier)
          .showError('Device disconnected');

      // Navigate back after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          context.go('/');
        }
      });
    }
  }

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

    return Scaffold(
      body: SafeArea(
        child: ResponsiveWrapper(
          child: !isConnected
              ? Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),

                      // Device ID Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                      ),

                      const SizedBox(height: 8),

                      // Grid for sensor data
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1.6,
                            ),
                        padding: const EdgeInsets.all(16),
                        itemCount: sensorData.length + 2,
                        itemBuilder: (context, index) {
                          if (index == 4) {
                            return _buildLEDCard(
                              'MODE 195',
                              machineData.func == '195',
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

                      // Bottom section
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildReadyCard(
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
                            const SizedBox(height: 20),
                            Text(
                              "Supply Voltage: ${machineData.voltage.replaceAll('.0', '')}V",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildTextRow(
                              "ENABLE (A): PIN 15",
                              machineData.pin15,
                              isDark,
                            ),
                            const SizedBox(height: 20),
                            _buildTextRow(
                              "ENABLE (B): PIN 6",
                              machineData.pin6,
                              isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, String> data, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // FIXED
          children: [
            Text(
              data['title']!.toUpperCase(),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8), // FIXED: Replaced Spacer()
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  data['value']!,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    data['unit']!,
                    style: TextStyle(
                      fontSize: 16,
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
    final ledColor = isActive
        ? AppColors.brandGreen
        : Theme.of(context).disabledColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // FIXED: Changed from max to min
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8), // FIXED: Replaced Spacer()
            Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ledColor,
                  boxShadow: [
                    if (isActive)
                      BoxShadow(
                        color: ledColor.withValues(alpha: 0.6),
                        blurRadius: 12,
                        spreadRadius: 4,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8), // FIXED: Replaced Spacer()
            Center(
              child: Text(
                isActive ? "ACTIVE" : "INACTIVE",
                style: TextStyle(
                  fontSize: 14,
                  color: ledColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Separate widget for READY card to avoid layout conflicts
  Widget _buildReadyCard(
    String title,
    bool isActive,
    BuildContext context,
    bool isDark,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final ledColor = isActive
        ? AppColors.brandGreen
        : Theme.of(context).disabledColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ledColor,
                    boxShadow: [
                      if (isActive)
                        BoxShadow(
                          color: ledColor.withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 4,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isActive ? "ACTIVE" : "INACTIVE",
                  style: TextStyle(
                    fontSize: 14,
                    color: ledColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextRow(String title, bool value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 20),
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
