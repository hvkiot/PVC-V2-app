import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScanning() async {
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
      if (mounted) {
        setState(() => isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bluetooth permissions not granted"),
            backgroundColor: Color(0xFFF56565),
          ),
        );
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Scan Error: ${e.toString()}"),
            backgroundColor: const Color(0xFFF56565),
          ),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error ?? "Connection failed"),
              backgroundColor: const Color(0xFFF56565),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

              // 1. Fixed the ParentDataWidget error by putting Expanded directly in Column
              // 2. Styled the box to match your sketch
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

  // Modified to remove its own Internal Expanded if you prefer,
  // but keeping it simple for now:
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
