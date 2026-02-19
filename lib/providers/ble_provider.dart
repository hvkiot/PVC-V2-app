import 'dart:async';
import 'dart:convert';
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

  const BleState({
    this.isScanning = false,
    this.connectedDevice,
    this.isConnecting = false,
    this.characteristicValue = '',
    this.connState = BluetoothConnectionState.disconnected,
    this.errorMessage,
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

  StreamSubscription? _connSub;
  StreamSubscription? _scanningSub;

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

  // 1. Add a flag to prevent auto-reconnect during manual disconnect
  bool _isManualDisconnect = false;

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _isManualDisconnect = false; // Reset flag
      state = state.copyWith(isConnecting: true);
      await FlutterBluePlus.stopScan();

      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // ONLY setup the listener if it's null to avoid duplicates
      _connSub ??= device.connectionState.listen((s) async {
        state = state.copyWith(connState: s);

        // Only auto-reconnect if it wasn't a manual disconnect
        if (s == BluetoothConnectionState.disconnected &&
            !_isManualDisconnect) {
          logger.w("Unexpected disconnect — retrying...");
          await Future.delayed(const Duration(seconds: 2));
          connectToDevice(device);
        }
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
      _isManualDisconnect = true; // Set flag to stop auto-reconnect
      _connSub?.cancel(); // Kill the listener
      _connSub = null;

      await state.connectedDevice!.disconnect();
      state = state.copyWith(
        clearConnectedDevice: true,
        characteristicValue: '',
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
                  logger.d("Received BLE Data: $decoded");
                  state = state.copyWith(characteristicValue: decoded);
                });

                return;
              } else {
                logger.w(
                  "Characteristic ${characteristic.uuid} does not support notify or indicate",
                );
              }
            }
          }
        }
      }

      logger.w(
        "Target Service $serviceUuid or Characteristic $charUuid not found on device",
      );
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

    try {
      List<BluetoothService> services = await state.connectedDevice!
          .discoverServices();

      for (var service in services) {
        if (service.uuid == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == charUuid) {
              if (characteristic.properties.write) {
                await characteristic.write(data.codeUnits);
                state = state.copyWith(clearError: true);
                return true;
              } else {
                logger.w(
                  "Characteristic ${characteristic.properties.write} $data is not writable",
                );
                state = state.copyWith(
                  errorMessage: "Characteristic is not writable",
                );
                return false;
              }
            }
          }
        }
      }
      state = state.copyWith(errorMessage: "Characteristic not found");
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: "Write error: ${e.toString()}");
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

  // Clear error message
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
