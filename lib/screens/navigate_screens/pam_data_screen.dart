import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
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
  Timer? _updateTimer;

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final bleState = ref.watch(bleProvider);
    final bleNotifier = ref.read(bleProvider.notifier);
    final theme = Theme.of(context);
    final isConnected = bleState.connectedDevice == device;
    final isDataAvailable = bleState.characteristicValue.isNotEmpty;

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
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          switch (index) {
                            case 0:
                              return const _InputACard();
                            case 1:
                              return const _CoilACard();
                            case 2:
                              return const _InputBCard();
                            case 3:
                              return const _CoilBCard();
                            case 4:
                              return const _Mode195Card();
                            case 5:
                              return const _Mode196Card();
                            default:
                              return const SizedBox.shrink();
                          }
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
                            const _ReadyCard(),
                            const SizedBox(height: 20),
                            const _VoltageDisplay(),
                            const SizedBox(height: 20),
                            const _PinRow(title: "ENABLE (A): PIN 15", pinName: 'pin15'),
                            const SizedBox(height: 20),
                            const _PinRow(title: "ENABLE (B): PIN 6", pinName: 'pin6'),
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
}

// --- Extracted sub-widgets with granular selects ---

class _InputACard extends ConsumerWidget {
  const _InputACard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      machineDataProvider.select((m) => (m.inputA, m.mode)),
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unit = data.$2 == 'C' ? 'mA' : 'V';

    return _SensorCard(
      title: 'INPUT A',
      value: UnitConverter.format(data.$1),
      unit: unit,
      colorScheme: colorScheme,
    );
  }
}

class _CoilACard extends ConsumerWidget {
  const _CoilACard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coilA = ref.watch(
      machineDataProvider.select((m) => m.coilA),
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _SensorCard(
      title: 'COIL A',
      value: UnitConverter.format(coilA),
      unit: 'mA',
      colorScheme: colorScheme,
    );
  }
}

class _InputBCard extends ConsumerWidget {
  const _InputBCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      machineDataProvider.select((m) => (m.inputB, m.mode)),
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unit = data.$2 == 'C' ? 'mA' : 'V';

    return _SensorCard(
      title: 'INPUT B',
      value: UnitConverter.format(data.$1),
      unit: unit,
      colorScheme: colorScheme,
    );
  }
}

class _CoilBCard extends ConsumerWidget {
  const _CoilBCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coilB = ref.watch(
      machineDataProvider.select((m) => m.coilB),
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _SensorCard(
      title: 'COIL B',
      value: UnitConverter.format(coilB),
      unit: 'mA',
      colorScheme: colorScheme,
    );
  }
}

class _Mode195Card extends ConsumerWidget {
  const _Mode195Card();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(
      machineDataProvider.select((m) => m.func == '195'),
    );
    return _LEDCard(title: 'MODE 195', isActive: isActive);
  }
}

class _Mode196Card extends ConsumerWidget {
  const _Mode196Card();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(
      machineDataProvider.select((m) => m.func == '196'),
    );
    return _LEDCard(title: 'MODE 196', isActive: isActive);
  }
}

class _ReadyCard extends ConsumerWidget {
  const _ReadyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      machineDataProvider.select(
        (m) => (m.ready, m.enableB, m.pin15, m.pin6),
      ),
    );
    return _ReadyCardWidget(data: data);
  }
}

class _VoltageDisplay extends ConsumerWidget {
  const _VoltageDisplay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voltage = ref.watch(
      machineDataProvider.select((m) => m.voltage),
    );
    final theme = Theme.of(context);
    return Text(
      "Supply Voltage: ${voltage.replaceAll('.0', '')}V",
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 24,
      ),
    );
  }
}

class _PinRow extends ConsumerWidget {
  final String title;
  final String pinName;

  const _PinRow({required this.title, required this.pinName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(
      machineDataProvider.select((m) {
        if (pinName == 'pin15') return m.pin15;
        if (pinName == 'pin6') return m.pin6;
        return false;
      }),
    );
    return _PinRowWidget(title: title, value: value);
  }
}

// --- Shared UI building blocks (no Riverpod logic) ---

class _SensorCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final ColorScheme colorScheme;

  const _SensorCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
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
}

class _LEDCard extends ConsumerWidget {
  final String title;
  final bool isActive;

  const _LEDCard({required this.title, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final ledColor = isActive
        ? AppColors.brandGreen
        : Theme.of(context).disabledColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
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
}

class _ReadyCardWidget extends StatelessWidget {
  final (String ready, bool enableB, bool pin15, bool pin6) data;

  const _ReadyCardWidget({required this.data});

  bool _led(String ready, bool pin15, bool pin6) {
    if (ready == "ALL OFF") return false;
    if (pin15 && pin6) return ready == "A + B ACTIVE";
    if (ready == "A ACTIVE" || ready == "B ACTIVE") return true;
    return false;
  }

  bool _ledStandard(String ready) => ready == "A + B ACTIVE";

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = data.$2
        ? _led(data.$1, data.$3, data.$4)
        : _ledStandard(data.$1);
    final ledColor = isActive
        ? AppColors.brandGreen
        : Theme.of(context).disabledColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Text(
              "READY ${data.$1}".toUpperCase(),
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
}

class _PinRowWidget extends StatelessWidget {
  final String title;
  final bool value;

  const _PinRowWidget({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 20),
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