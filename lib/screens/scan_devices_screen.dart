import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/routes/static_routes.dart';
import 'package:pvc_v2/theme/app_colors.dart';
import 'package:pvc_v2/utils/responsive_helper.dart';
import 'package:pvc_v2/widgets/custom_app_bar.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AvailableDevicesScreen extends ConsumerStatefulWidget {
  const AvailableDevicesScreen({super.key});

  @override
  ConsumerState<AvailableDevicesScreen> createState() =>
      _AvailableDevicesScreenState();
}

class _AvailableDevicesScreenState extends ConsumerState<AvailableDevicesScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final List<BluetoothDevice> validDevices = [];
  final List<BluetoothDevice> _pendingDevices = [];
  bool isScanning = false;
  BluetoothDevice? selectedDevice;
  bool _justConnected =
      false; // Prevents disconnect guard from killing fresh connection

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  late StreamSubscription<BluetoothAdapterState> _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _isLocationServiceEnabled = true;
  DateTime? _scanStartTime;
  DateTime? _lastScanEnd;
  static const Duration _scanCooldown = Duration(seconds: 3);
  static const Duration _minScanDuration = Duration(seconds: 2);
  bool _acceptResults = false;
  bool _isReScan = false;
  bool _isStartingScan = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addObserver(this);
    validDevices.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _forceStopNativeScan();
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

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!_acceptResults || !mounted) return;
      for (var result in results) {
        final name = result.device.platformName.trim();
        if (name.isEmpty ||
            name.toLowerCase().contains('unknown') ||
            name.toLowerCase().contains('device')) {
          continue;
        }
        final isPending = _pendingDevices.any(
          (d) => d.remoteId == result.device.remoteId,
        );
        if (validDevices.any((d) => d.remoteId == result.device.remoteId) ||
            isPending) {
          continue;
        }
        if (_isReScan) {
          final elapsed = DateTime.now().difference(_scanStartTime!);
          if (elapsed < _minScanDuration) {
            setState(() => _pendingDevices.add(result.device));
          } else {
            setState(() => validDevices.add(result.device));
          }
        } else {
          setState(() => validDevices.add(result.device));
        }
      }
    }, onError: (Object error) {
      _onScanStreamError(error);
    });
  }

  /// Force the native scanner to stop, bypassing flutter_blue_plus's Dart-side
  /// `isScanningNow` gate. After an app restart the native scan can survive while
  /// the plugin's Dart state is fresh, so the public stopScan() is a no-op and the
  /// next startScan() fails with SCAN_FAILED_ALREADY_STARTED.
  Future<void> _forceStopNativeScan() async {
    try {
      await FlutterBluePlusPlatform.instance.stopScan(BmStopScanRequest());
    } catch (_) {
      // Plugin not ready or unsupported platform — nothing to force stop.
    }
  }

  /// Recovers from a scan stream error (e.g. SCAN_FAILED_ALREADY_STARTED left over
  /// from a previous app session): force-stop the native scanner, then re-scan.
  Future<void> _onScanStreamError(Object error) async {
    if (!mounted) return;
    _acceptResults = false;
    setState(() {
      isScanning = false;
    });
    await _forceStopNativeScan();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _lastScanEnd = null;
    _startScanning();
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
    _pulseController.dispose();
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
    if (_isStartingScan) return;
    _isStartingScan = true;

    try {
      if (_adapterState != BluetoothAdapterState.on) return;
      if (isScanning) return;
      if (_lastScanEnd != null &&
          DateTime.now().difference(_lastScanEnd!) < _scanCooldown) {
        return;
      }

      // Clear any native scan left running from a previous app session before
      // starting a fresh scan, so startScan() cannot fail with
      // SCAN_FAILED_ALREADY_STARTED.
      await _forceStopNativeScan();

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

      _isReScan = validDevices.isNotEmpty;

      setState(() {
        isScanning = true;
        _scanStartTime = DateTime.now();
        _pendingDevices.clear();
        if (_isReScan) {
          validDevices.clear();
        }
      });

      // Check permissions
      var scanStatus = await Permission.bluetoothScan.request();
      var connectStatus = await Permission.bluetoothConnect.request();
      var locationStatus = await Permission.location.request();

      if (!scanStatus.isGranted ||
          !connectStatus.isGranted ||
          !locationStatus.isGranted) {
        setState(() {
          isScanning = false;
          _lastScanEnd = DateTime.now();
        });
        ref
            .read(globalMessageProvider.notifier)
            .showError("Bluetooth permissions not granted");
        return;
      }

      try {
        final serviceUuid = ref.read(bleProvider.notifier).getServiceUuid;
        _acceptResults = true;

        // On some devices (Huawei), BLE scans are limited to ~200ms.
        // Retry multiple times to accumulate enough scan time.
        const int maxRetries = 5;
        int retries = 0;
        while (retries < maxRetries) {
          retries++;
          if (retries > 1) {
            await Future.delayed(const Duration(milliseconds: 400));
          }
          await FlutterBluePlus.startScan(
            withServices: [serviceUuid],
            timeout: const Duration(seconds: 10),
          );
          await Future.delayed(const Duration(milliseconds: 50));
          final hasDevices =
              validDevices.isNotEmpty || _pendingDevices.isNotEmpty;
          final elapsed = DateTime.now().difference(_scanStartTime!);
          if (hasDevices || elapsed >= const Duration(seconds: 3)) break;
        }

        _acceptResults = false;

        if (mounted) {
          if (_isReScan) {
            // Enforce minimum scan duration so re-scan doesn't look instant
            final elapsed = DateTime.now().difference(_scanStartTime!);
            if (elapsed < _minScanDuration) {
              await Future.delayed(_minScanDuration - elapsed);
            }
            // Flush pending devices into valid list
            if (_pendingDevices.isNotEmpty && mounted) {
              setState(() {
                validDevices.addAll(_pendingDevices);
                _pendingDevices.clear();
              });
            }
          }
          setState(() {
            isScanning = false;
            _lastScanEnd = DateTime.now();
          });
        }
      } catch (e) {
        _acceptResults = false;
        if (mounted) {
          setState(() {
            isScanning = false;
            _lastScanEnd = DateTime.now();
          });
          if (!e.toString().contains("turned on")) {
            ref.read(globalMessageProvider.notifier).showError(e.toString());
          }
        }
      }
    } finally {
      _isStartingScan = false;
    }
  }

  Future<void> _handleConnect(BluetoothDevice device) async {
    _justConnected = true;
    try {
      bool success = false;
      for (int attempt = 0; attempt < 2 && !success; attempt++) {
        if (attempt > 0) {
          if (!mounted) return;
          ref
              .read(globalMessageProvider.notifier)
              .showError("Retrying connection...");
          await Future.delayed(const Duration(seconds: 1));
        }
        success = await ref.read(bleProvider.notifier).connectToDevice(device);
      }

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
            onPressed: () {
              isScanning ? null : _startScanning();
            },
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
                brandButton(),
                const SizedBox(height: 20),
                Semantics(
                  label: isScanning ? 'Scanning for devices' : 'Device list',
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: isScanning ? _pulseAnimation.value : 1.0,
                        child: Text(
                          isScanning ? 'SCANNING' : 'AVAILABLE DEVICES',
                          style: theme.textTheme.titleMedium?.copyWith(
                            letterSpacing: 2.0,
                          ),
                        ),
                      );
                    },
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

  Container brandButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brandBlue, width: 0.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          InkWell(
            onTap: () async {
              try {
                await launchUrlString(
                  'https://hvksystems.in/',
                  mode: LaunchMode.externalApplication,
                );
              } catch (e) {
                ref
                    .read(globalMessageProvider.notifier)
                    .showError("Could not open HVK website");
              }
            },
            child: Column(
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
          ),
          SizedBox(
            height: 60,
            child: VerticalDivider(
              color: Colors.red,
              thickness: 1.5,
              width: 15,
            ),
          ),
          InkWell(
            onTap: () async {
              try {
                await launchUrlString(
                  'https://www.w-e-st.de/wp/en/',
                  mode: LaunchMode.externalApplication,
                );
              } catch (e) {
                ref
                    .read(globalMessageProvider.notifier)
                    .showError("Could not open WEST website");
              }
            },
            child: Column(
              children: [
                Text(
                  'Powered by',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Image.asset('assets/WEST.png', width: 100, height: 50),
              ],
            ),
          ),
        ],
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
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _pulseAnimation.value.clamp(0.3, 0.7),
          child: child,
        );
      },
      child: Container(
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
        final displayName = device.platformName.isNotEmpty
            ? device.platformName
            : 'Device · ${device.remoteId.toString().substring(device.remoteId.toString().length - 4).toUpperCase()}';

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 80)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Semantics(
            label: '$displayName device',
            button: true,
            selected: isSelected,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: ListTile(
                selected: isSelected,
                title: Text(displayName),
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
