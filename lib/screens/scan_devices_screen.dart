import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/routes/static_routes.dart';
import 'package:pvc_v2/theme/app_colors.dart';
import 'package:pvc_v2/utils/responsive_helper.dart';
import 'package:pvc_v2/widgets/custom_app_bar.dart';

class AvailableDevicesScreen extends ConsumerStatefulWidget {
  const AvailableDevicesScreen({super.key});

  @override
  ConsumerState<AvailableDevicesScreen> createState() =>
      _AvailableDevicesScreenState();
}

class _AvailableDevicesScreenState extends ConsumerState<AvailableDevicesScreen>
    with WidgetsBindingObserver {
  final List<BluetoothDevice> validDevices = [];
  bool isScanning = false;
  BluetoothDevice? selectedDevice;
  bool _justConnected =
      false; // Prevents disconnect guard from killing fresh connection

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  late StreamSubscription<BluetoothAdapterState> _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _isLocationServiceEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    validDevices.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationService();
    });

    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _adapterState = state;
        });
        if (state == BluetoothAdapterState.on &&
            _isLocationServiceEnabled &&
            !isScanning) {
          _startScanning();
        }
      }
    });
  }

  /// Disconnect any lingering BLE connection when scan screen becomes the active route.
  /// Skips if a connection was just initiated by the user from this screen.
  void _ensureDisconnectedOnRouteActive() {
    if (_justConnected) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    final bleState = ref.read(bleProvider);
    if (bleState.connectedDevice == null || bleState.isConnecting) return;
    Future.microtask(() {
      if (mounted) ref.read(bleProvider.notifier).disconnectFromDevice();
    });
  }

  /// Clear stale devices when the previously connected device disconnects
  void _onBleDisconnect(BluetoothDevice? prevDevice) {
    if (prevDevice != null && mounted) {
      validDevices.clear();
      if (!isScanning) {
        _startScanning();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adapterStateSubscription.cancel();
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    validDevices.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkLocationService();
      });
    }
  }

  Future<void> _checkLocationService() async {
    // Bluetooth scanning requires Location Services to be enabled on Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.location.serviceStatus;
      if (mounted) {
        setState(() {
          _isLocationServiceEnabled = status.isEnabled;
        });
        if (status.isEnabled &&
            _adapterState == BluetoothAdapterState.on &&
            !isScanning) {
          _startScanning();
        }
      }
    }
  }

  Future<void> _startScanning() async {
    if (_adapterState != BluetoothAdapterState.on) return;

    // Double check location service on Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.location.serviceStatus;
      if (!status.isEnabled) {
        if (mounted) {
          setState(() => _isLocationServiceEnabled = false);
        }
        return;
      }
    }

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

      // Cancel previous subscription to avoid duplicates
      _scanSub?.cancel();

      // Subscribe to scan results BEFORE starting scan
      // so devices appear immediately as they're discovered
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          if (validDevices.any((d) => d.remoteId == result.device.remoteId)) {
            continue;
          }
          final advertisedServices = result.advertisementData.serviceUuids;
          if (advertisedServices.contains(serviceUuid)) {
            if (mounted) {
              setState(() {
                validDevices.add(result.device);
              });
            }
          }
        }
      });

      // Start scan — await blocks until the 10s timeout or stopScan
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      if (mounted) {
        setState(() => isScanning = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isScanning = false);
        if (!e.toString().contains("turned on")) {
          ref.read(globalMessageProvider.notifier).showError(e.toString());
        }
      }
    }
  }

  Future<void> _handleConnect(BluetoothDevice device) async {
    _justConnected = true;
    try {
      await FlutterBluePlus.stopScan();

      final success = await ref
          .read(bleProvider.notifier)
          .connectToDevice(device);

      if (mounted) {
        if (success) {
          context.push(AppRoutes.details, extra: device);
        } else {
          final error = ref.read(bleProvider).errorMessage;
          ref
              .read(globalMessageProvider.notifier)
              .showError(error ?? "Connection failed");
        }
      }
    } catch (e) {
      final error = e.toString();
      ref.read(globalMessageProvider.notifier).showError(error);
    } finally {
      _justConnected = false;
    }
  }

  Future<void> openLocationSettings() async {
    try {
      const intent = AndroidIntent(
        action: 'android.settings.LOCATION_SOURCE_SETTINGS',
      );
      await intent.launch();
    } catch (e) {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Disconnect any lingering BLE connection when arriving at scan screen
    _ensureDisconnectedOnRouteActive();

    // Clear stale devices when the previously connected device disconnects
    ref.listen(bleProvider, (prev, next) {
      if (prev?.connectedDevice != null && next.connectedDevice == null) {
        _onBleDisconnect(prev?.connectedDevice);
      }
    });

    // If bluetooth is off, show the special screen immediately
    if (_adapterState == BluetoothAdapterState.off) {
      return _buildBluetoothOffScreen(context);
    }

    // If location is off (on Android), show the special screen
    if (!_isLocationServiceEnabled) {
      return _buildLocationOffScreen(context);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: CustomAppBar(
        title: 'PROPORTIONAL VALVE CHECKER',
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
        child: ResponsiveWrapper(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Match Sketch Title
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lightBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.brandBlue, width: 0.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Designed & Developed by',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Image.asset('assets/HVK.png', width: 100, height: 50),
                        ],
                      ),
                      SizedBox(
                        height: 60,
                        child: VerticalDivider(
                          color: Colors.red,
                          thickness: 1.5,
                          width: 15,
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            'Powered by',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Image.asset(
                            'assets/WEST.png',
                            width: 100,
                            height: 50,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  label: isScanning ? 'Scanning for devices' : 'Device list',
                  child: Text(
                    'SCANNING',
                    style: theme.textTheme.titleMedium?.copyWith(
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: deviceList(),
                    ),
                  ),
                ),

                // 3. Action Buttons
                connectButton(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationOffScreen(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'HVK'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 100,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              const Text(
                'Location is Off',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Location services are required to scan for available devices on this platform.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  // This will open the system location settings screen directly
                  await openLocationSettings();
                },
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
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
                    if (defaultTargetPlatform == TargetPlatform.android) {
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

  Widget _shimmerItem() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withAlpha(50)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.disabledColor.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: theme.disabledColor.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget deviceList() {
    final theme = Theme.of(context);
    final showShimmer = isScanning && validDevices.isEmpty;
    if (showShimmer) {
      return ListView.builder(
        key: const ValueKey('shimmer'),
        itemCount: 5,
        itemBuilder: (context, index) => _shimmerItem(),
      );
    }
    if (validDevices.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No devices found',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap refresh to search',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('list'),
      itemCount: validDevices.length,
      itemBuilder: (context, index) {
        final device = validDevices[index];
        final isSelected = selectedDevice?.remoteId == device.remoteId;

        return Semantics(
          label:
              '${device.platformName.isEmpty ? 'Unknown' : device.platformName} device',
          button: true,
          selected: isSelected,
          child: Container(
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
                  if (isSelected) {
                    selectedDevice = null;
                  } else {
                    selectedDevice = device;
                  }
                });
              },
            ),
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
