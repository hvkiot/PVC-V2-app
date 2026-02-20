import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/routes/static_routes.dart';
import 'package:pvc_v2/widgets/custom_app_bar.dart';

class AvailableDevicesScreen extends ConsumerStatefulWidget {
  const AvailableDevicesScreen({super.key});

  @override
  ConsumerState<AvailableDevicesScreen> createState() =>
      _AvailableDevicesScreenState();
}

class _AvailableDevicesScreenState
    extends ConsumerState<AvailableDevicesScreen> {
  final List<BluetoothDevice> validDevices = [];
  bool isScanning = false;
  BluetoothDevice? selectedDevice; // Track selection

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  late StreamSubscription<BluetoothAdapterState> _adapterStateSubscription;

  @override
  void initState() {
    super.initState();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _adapterState = state;
        });
        if (state == BluetoothAdapterState.on && !isScanning) {
          _startScanning();
        }
      }
    });
  }

  @override
  void dispose() {
    _adapterStateSubscription.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScanning() async {
    if (_adapterState != BluetoothAdapterState.on) return;

    setState(() {
      isScanning = true;
      validDevices.clear();
    });

    // Check permissions
    var scanStatus = await Permission.bluetoothScan.request();
    var connectStatus = await Permission.bluetoothConnect.request();
    var locationStatus = await Permission.location.request();

    if (!scanStatus.isGranted ||
        !connectStatus.isGranted ||
        !locationStatus.isGranted) {
      setState(() => isScanning = false);
      ref
          .read(globalMessageProvider.notifier)
          .showError("Bluetooth permissions not granted");

      return;
    }

    try {
      final serviceUuid = ref.read(bleProvider.notifier).getServiceUuid;

      // Start scanning
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // Listen for scan results
      FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          // Check if device already in list
          if (validDevices.any((d) => d.remoteId == result.device.remoteId)) {
            continue;
          }

          // Check advertised service UUIDs (no connection needed)
          final advertisedServices = result.advertisementData.serviceUuids;

          // Check if the device advertises our service UUID
          if (advertisedServices.contains(serviceUuid)) {
            if (mounted) {
              setState(() {
                validDevices.add(result.device);
              });
            }
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));

      if (mounted) {
        setState(() => isScanning = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isScanning = false);
        // We handle the "off" state proactively now, so we can likely suppress generic errors or keep them as backup
        if (!e.toString().contains("turned on")) {
          ref.read(globalMessageProvider.notifier).showError(e.toString());
        }
      }
    }
  }

  Future<void> _handleConnect(BluetoothDevice device) async {
    try {
      // 2. Stop scanning before attempting to connect (best practice)
      await FlutterBluePlus.stopScan();

      // 3. Use the Riverpod notifier to initiate connection
      // This will update the state in your bleProvider
      final success = await ref
          .read(bleProvider.notifier)
          .connectToDevice(device);

      if (mounted) {
        if (success) {
          // 4. Navigate to details only if connection succeeded
          context.push(AppRoutes.details, extra: device);
        } else {
          // Connection failed, show error from the provider state
          final error = ref.read(bleProvider).errorMessage;
          ref
              .read(globalMessageProvider.notifier)
              .showError(error ?? "Connection failed");
        }
      }
    } catch (e) {
      final error = e.toString();
      ref.read(globalMessageProvider.notifier).showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If bluetooth is off, show the special screen immediately
    if (_adapterState == BluetoothAdapterState.off) {
      return _buildBluetoothOffScreen(context);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: CustomAppBar(
        title: 'HVK',
        preferredSizeChild: isScanning
            ? const LinearProgressIndicator()
            : const SizedBox(height: 1.0),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isScanning
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.primary,
            ),
            onPressed: () => isScanning ? null : _startScanning(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Match Sketch Title
              const Text(
                'PROPORTIONAL VALVE CHECKER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'SCANNING',
                style: TextStyle(fontSize: 16, letterSpacing: 2.0),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  child: deviceList(),
                ),
              ),

              // 3. Action Buttons
              connectButton(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBluetoothOffScreen(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'HVK'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bluetooth_disabled,
                size: 100,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              const Text(
                'Bluetooth is Off',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please enable Bluetooth to scan for available devices.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    if (Theme.of(context).platform == TargetPlatform.android) {
                      await FlutterBluePlus.turnOn();
                    } else {
                      // iOS doesn't allow programmatically turning on BT, usually we open settings if possible or just show a message,
                      // but FlutterBluePlus.turnOn() handles Android.
                      // For simplicity we just try to call it, or we could just rely on the user.
                      // Since we are reactive, if they pull down control center and enable it, the UI updates automatically.
                      ref
                          .read(globalMessageProvider.notifier)
                          .showError("Please enable Bluetooth in settings");
                    }
                  } catch (e) {
                    ref
                        .read(globalMessageProvider.notifier)
                        .showError("Could not turn on Bluetooth");
                  }
                },
                icon: const Icon(Icons.bluetooth),
                label: const Text('Turn On Bluetooth'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget deviceList() {
    if (validDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isScanning ? 'Searching for devices...' : 'No devices found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),

            if (!isScanning) ...[
              const SizedBox(height: 8),
              Text(
                'Tap "refresh icon" to search',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: validDevices.length,
      itemBuilder: (context, index) {
        final device = validDevices[index];
        // Check if this device is the one selected
        final isSelected = selectedDevice?.remoteId == device.remoteId;

        return Container(
          padding: const EdgeInsets.all(8),
          child: ListTile(
            selected: isSelected,
            title: Text(
              device.platformName.isEmpty
                  ? 'Unknown Device'
                  : device.platformName,
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle)
                : const Icon(Icons.radio_button_unchecked, size: 16),
            onTap: () {
              setState(() {
                // Deselect if tapping the same device, otherwise select new
                if (isSelected) {
                  selectedDevice = null;
                } else {
                  selectedDevice = device;
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget connectButton() {
    final isConnecting = ref.watch(bleProvider).isConnecting;
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: (selectedDevice != null && !isConnecting)
            ? () => _handleConnect(selectedDevice!)
            : null,
        child: Text(isConnecting ? 'CONNECTING...' : 'CONNECT'),
      ),
    );
  }
}
