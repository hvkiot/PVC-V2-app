import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/models/machine_data.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/theme/app_colors.dart';

class PamDataScreen extends ConsumerStatefulWidget {
  final BluetoothDevice device;
  const PamDataScreen({super.key, required this.device});

  @override
  ConsumerState<PamDataScreen> createState() => _PamDataScreenState();
}

class _PamDataScreenState extends ConsumerState<PamDataScreen> {
  final List<BluetoothDevice> validDevices = [];

  bool isScanning = false;

  late final ProviderSubscription<BleState> _bleListener;

  late final BleNotifier _bleNotifier;

  @override
  void initState() {
    super.initState();

    // Use read for the notifier as it's a one-time setup
    _bleNotifier = ref.read(bleProvider.notifier);

    // Listeners are fine in initState for side-effects (errors, dialogs)
    _bleListener = ref.listenManual<BleState>(bleProvider, (previous, next) {
      if (!mounted) return;

      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: const Color(0xFFF56565),
          ),
        );
        _bleNotifier.clearError();
      }
    });
  }

  @override
  void dispose() {
    _bleListener.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final bleState = ref.watch(bleProvider);
    final machineData = MachineData.fromPacket(bleState.characteristicValue);
    // print(bleState.characteristicValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Map<String, String>> sensorData = [
      {
        'title': 'INPUT A',
        'value':
            double.tryParse(machineData.inputA)?.toStringAsFixed(1) ?? '0.00',
        'unit': 'V',
      },
      {'title': 'COIL A', 'value': machineData.coilA, 'unit': 'mA'},
      {
        'title': 'INPUT B',
        'value':
            double.tryParse(machineData.inputB)?.toStringAsFixed(1) ?? '0.00',
        'unit': 'V',
      },
      {'title': 'COIL B', 'value': machineData.coilB, 'unit': 'mA'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Device ID: ${device.platformName.replaceAll('PVC-', '')}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (bleState.connectedDevice == device)
              Icon(
                Icons.bluetooth_connected,
                color: isDark ? AppColors.brandCyan : AppColors.brandRed,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (bleState.connectedDevice != null &&
            bleState.characteristicValue.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Waiting for Data..."),
                ],
              ),
            ),
          )
        else
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
          child: SizedBox(
            width: 200,
            child: Column(
              children: [
                Expanded(
                  child: _buildLEDCard(
                    'READY',
                    machineData.mode == 'V',
                    context,
                    isDark,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Raw: ${bleState.characteristicValue}",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
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
        : Colors.grey.withValues(alpha: 0.3);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
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
}
