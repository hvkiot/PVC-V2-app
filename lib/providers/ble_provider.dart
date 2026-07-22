import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:pvc_v2/models/machine_data.dart';

// State class to hold all BLE-related state
class BleState {
  final bool isScanning;
  final BluetoothDevice? connectedDevice;
  final bool isConnecting;
  final String characteristicValue;
  final BluetoothConnectionState connState;
  final String? errorMessage;
  final List<String> serialLog;
  final bool isBusy;

  const BleState({
    this.isScanning = false,
    this.connectedDevice,
    this.isConnecting = false,
    this.characteristicValue = '',
    this.connState = BluetoothConnectionState.disconnected,
    this.errorMessage,
    this.serialLog = const [],
    this.isBusy = false,
  });

  BleState copyWith({
    bool? isScanning,
    BluetoothDevice? connectedDevice,
    bool? isConnecting,
    String? characteristicValue,
    BluetoothConnectionState? connState,
    String? errorMessage,
    bool clearConnectedDevice = false,
    bool clearError = false,
    List<String>? serialLog,
    bool? isBusy,
  }) {
    return BleState(
      isScanning: isScanning ?? this.isScanning,
      connectedDevice: clearConnectedDevice
          ? null
          : (connectedDevice ?? this.connectedDevice),
      isConnecting: isConnecting ?? this.isConnecting,
      characteristicValue: characteristicValue ?? this.characteristicValue,
      connState: connState ?? this.connState,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      serialLog: serialLog ?? this.serialLog,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

// Notifier class for BLE operations
class BleNotifier extends Notifier<BleState> {
  // Logger instance
  final Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
  );

  // BLE Service and Characteristic UUIDs
  final Guid serviceUuid = Guid("12345678-1234-5678-1234-56789abcdef0");
  final Guid charUuid = Guid("12345678-1234-5678-1234-56789abcdef1");
  final Guid logServiceUuid = Guid("12345678-1234-5678-1234-56789abcdef2");
  final Guid logCharUuid = Guid("12345678-1234-5678-1234-56789abcdef3");

  StreamSubscription? _connSub;
  StreamSubscription? _scanningSub;
  StreamSubscription? _logSub;

  @override
  BleState build() {
    // Initialize scanning state listener
    _scanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      state = state.copyWith(isScanning: scanning);
    });

    // Cleanup on dispose
    ref.onDispose(() {
      _cleanup();
    });

    return const BleState();
  }

  void _cleanup() {
    _connSub?.cancel();
    _scanningSub?.cancel();
    _logSub?.cancel();
    if (state.connectedDevice != null) {
      state.connectedDevice!.disconnect();
    }
  }

  Future<bool> scanDevices() async {
    // Check if Bluetooth is supported
    if (await FlutterBluePlus.isSupported == false) {
      state = state.copyWith(
        errorMessage: "Bluetooth not supported on this device",
      );
      return false;
    }

    // Check if Bluetooth is ON
    var adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      state = state.copyWith(errorMessage: "Please turn on Bluetooth to scan");
      return false;
    }

    // Start scanning
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      state = state.copyWith(clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      state = state.copyWith(isConnecting: true);
      await FlutterBluePlus.stopScan();

      // Small delay to let the Bluetooth stack settle after stopping scan
      await Future.delayed(const Duration(milliseconds: 200));

      // Disconnect first to clear stale GATT state (fixes ANDROID_SPECIFIC_ERROR)
      try {
        await device.disconnect();
      } catch (_) {
        // Ignore — device was already disconnected
      }
      await Future.delayed(const Duration(milliseconds: 100));

      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // ONLY setup the listener if it's null to avoid duplicates
      _connSub ??= device.connectionState.listen((s) {
        state = state.copyWith(connState: s);
      });

      await device.connectionState
          .where((s) => s == BluetoothConnectionState.connected)
          .first;
      state = state.copyWith(connectedDevice: device);
      await _discoverServices(device);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: "Connection failed: $e");
      return false;
    } finally {
      state = state.copyWith(isConnecting: false);
    }
  }

  Future<bool> disconnectFromDevice() async {
    if (state.connectedDevice != null) {
      _connSub?.cancel();
      _connSub = null;
      _logSub?.cancel();
      _logSub = null;

      await state.connectedDevice!.disconnect();
      state = state.copyWith(
        clearConnectedDevice: true,
        characteristicValue: '',
        serialLog: [],
        isBusy: false,
      );
      return true;
    }
    return false;
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      // ✅ ensure still connected
      final deviceState = await device.connectionState.first;
      if (deviceState != BluetoothConnectionState.connected) {
        logger.w("Device not connected when attempting to discover services");
        return;
      }

      List<BluetoothService> services;
      try {
        services = await device.discoverServices();
      } catch (e) {
        // retry once after short delay
        await Future.delayed(const Duration(milliseconds: 600));
        services = await device.discoverServices();
      }

      for (var service in services) {
        logger.d("Found Service: ${service.uuid}");

        if (service.uuid == serviceUuid) {
          for (var characteristic in service.characteristics) {
            logger.d(
              "Found Characteristic: ${characteristic.uuid} Properties: ${characteristic.properties}",
            );
            if (characteristic.uuid == charUuid) {
              if (characteristic.properties.notify ||
                  characteristic.properties.indicate) {
                await characteristic.setNotifyValue(true);
                logger.i(
                  "Subscribed to characteristic: ${characteristic.uuid}",
                );

                characteristic.onValueReceived.listen((value) {
                  final decoded = utf8.decode(value, allowMalformed: true);
                  // logger.d("Received BLE Data: $decoded");
                  state = state.copyWith(characteristicValue: decoded);
                  if (decoded.contains('TRANSITION:False')) {
                    state = state.copyWith(isBusy: false);
                  }
                });
              } else {
                logger.w(
                  "Characteristic ${characteristic.uuid} does not support notify or indicate",
                );
              }
            }
          }
        }

        if (service.uuid == logServiceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == logCharUuid) {
              if (characteristic.properties.notify ||
                  characteristic.properties.indicate) {
                await characteristic.setNotifyValue(true);
                logger.i("Subscribed to log characteristic");

                _logSub = characteristic.onValueReceived.listen((value) {
                  final decoded = utf8.decode(value, allowMalformed: true);
                  final ts = _timestamp();
                  final updated = [...state.serialLog, "$ts LOG: $decoded"];
                  updated.removeRange(0, max(0, updated.length - 500));
                  state = state.copyWith(serialLog: updated);
                });
              }
            }
          }
        }
      }

      state = state.copyWith(errorMessage: "Service not found - check logs");
    } catch (e) {
      logger.e("Error discovering services", error: e);
    }
  }

  Future<bool> writeToCharacteristic(String data) async {
    if (state.connectedDevice == null) {
      state = state.copyWith(errorMessage: "No device connected");
      return false;
    }

    if (state.isBusy) {
      logger.w("⚠️ Dropped command (busy): $data");
      return false;
    }

    setBusy(true);

    try {
      List<BluetoothService> services = await state.connectedDevice!
          .discoverServices();

      for (var service in services) {
        if (service.uuid == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == charUuid) {
              if (characteristic.properties.write) {
                await characteristic.write(data.codeUnits);
                final ts = _timestamp();
                final updated = [...state.serialLog, "$ts TX: $data"];
                updated.removeRange(0, max(0, updated.length - 500));
                state = state.copyWith(clearError: true, serialLog: updated);
                return true;
              } else {
                logger.w(
                  "Characteristic ${characteristic.properties.write} $data is not writable",
                );
                state = state.copyWith(
                  errorMessage: "Characteristic is not writable",
                  isBusy: false,
                );
                return false;
              }
            }
          }
        }
      }
      state = state.copyWith(
        errorMessage: "Characteristic not found",
        isBusy: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: "Write error: ${e.toString()}",
        isBusy: false,
      );
      return false;
    }
  }

  Future<String?> readFromCharacteristic() async {
    if (state.connectedDevice == null) {
      state = state.copyWith(errorMessage: "No device connected");
      return null;
    }

    try {
      List<BluetoothService> services = await state.connectedDevice!
          .discoverServices();

      for (var service in services) {
        if (service.uuid == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == charUuid) {
              if (characteristic.properties.read) {
                List<int> value = await characteristic.read();
                String result = String.fromCharCodes(value);
                state = state.copyWith(
                  characteristicValue: result,
                  clearError: true,
                );
                return result;
              } else {
                state = state.copyWith(
                  errorMessage: "Characteristic is not readable",
                );
                return null;
              }
            }
          }
        }
      }
      state = state.copyWith(errorMessage: "Characteristic not found");
      return null;
    } catch (e) {
      logger.e('Error reading from characteristic', error: e);
      state = state.copyWith(errorMessage: "Read error: ${e.toString()}");
      return null;
    }
  }

  // Get the service UUID for filtering
  Guid get getServiceUuid => serviceUuid;

  String _timestamp() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void clearSerialLog() {
    state = state.copyWith(serialLog: []);
  }

  // Clear error message
  // Set/clear the optimistic transition lock
  void setBusy(bool value) {
    state = state.copyWith(isBusy: value);
    if (value) {
      // Safety timeout: auto-clear after 8s if hardware never responds
      Timer(const Duration(seconds: 8), () {
        if (state.isBusy) {
          logger.w("⚠️ Busy guard timed out — forcing unlock");
          state = state.copyWith(isBusy: false);
        }
      });
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

// Provider for BLE state management
final bleProvider = NotifierProvider<BleNotifier, BleState>(() {
  return BleNotifier();
});

// Stream provider for scan results
final scanResultsProvider = StreamProvider<List<ScanResult>>((ref) {
  return FlutterBluePlus.scanResults.map(
    (results) =>
        results.where((r) => r.device.platformName.isNotEmpty).toList(),
  );
});

/// A provider that automatically parses the raw BLE string into a MachineData object.
final machineDataProvider = Provider<MachineData>((ref) {
  // Watch the raw BLE state
  final bleState = ref.watch(bleProvider);

  // Return the parsed model
  return MachineData.fromPacket(bleState.characteristicValue);
});
