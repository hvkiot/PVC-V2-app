import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:pvc_v2/models/machine_data.dart';
import 'package:pvc_v2/utils/pvc_debug_trace.dart';

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
  final MachineData machineData;

  BleState({
    this.isScanning = false,
    this.connectedDevice,
    this.isConnecting = false,
    this.characteristicValue = '',
    this.connState = BluetoothConnectionState.disconnected,
    this.errorMessage,
    this.serialLog = const [],
    this.isBusy = false,
    this.machineData = const MachineData(),
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
    MachineData? machineData,
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
      machineData: machineData ?? this.machineData,
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
  StreamSubscription<List<int>>? _telemetrySub;
  StreamSubscription? _logSub;

  // Single outstanding busy-guard safety timer. setBusy() cancels/replaces
  // this on every call so a stale timer from an earlier operation can never
  // fire after busy has already been legitimately cleared/reset.
  Timer? _busyTimer;

  // Cached main command characteristic.  It is set after service discovery
  // and cleared on disconnect or before a new connect.
  BluetoothCharacteristic? _cmdCharacteristic;

  // ---- F| chunk reassembly state (temporary debug) ----
  final List<String> _fChunks = [];
  int _fExpectedTotal = 0;
  int _fSnapshotId = 0;

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

    return BleState();
  }

  void _cleanup() {
    _connSub?.cancel();
    _scanningSub?.cancel();
    _telemetrySub?.cancel();
    _logSub?.cancel();
    _busyTimer?.cancel();
    _busyTimer = null;
    _cmdCharacteristic = null;
    _fChunks.clear();
    _fExpectedTotal = 0;
    _fSnapshotId = 0;
    if (state.connectedDevice != null) {
      state.connectedDevice!.disconnect();
    }
    // Reset machineData to default on full cleanup
    state = state.copyWith(machineData: const MachineData());
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
      await Future.delayed(const Duration(milliseconds: 300));

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
      // Cache will be cleared in _discoverServices; clear any stale reference
      _cmdCharacteristic = null;
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
      _telemetrySub?.cancel();
      _telemetrySub = null;
      _logSub?.cancel();
      _logSub = null;
      _cmdCharacteristic = null;
      // Clear F| chunk reassembly state
      _fChunks.clear();
      _fExpectedTotal = 0;
      _fSnapshotId = 0;

      await state.connectedDevice!.disconnect();
      state = state.copyWith(
        clearConnectedDevice: true,
        characteristicValue: '',
        serialLog: [],
        isBusy: false,
        machineData: const MachineData(),
      );
      return true;
    }
    return false;
  }

  /// Asks the kit to emit a fresh F| full snapshot.
  ///
  /// FUNC and MODE only travel in F| (full) and D| (delta) packets — the 200ms
  /// L| live packet does not carry them. The kit emits one F| from its
  /// onConnect handler, but that fires at GATT link-up, typically before this
  /// side has finished MTU negotiation + service discovery and enabled
  /// notifications, so the stack silently drops it. This asks for another one
  /// at a moment when the notify channel is known to be open.
  Future<bool> requestSync() async {
    logger.i("→ SYNC (requesting full snapshot)");
    return writeRawToCharacteristic('SYNC');
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      // ✅ ensure still connected
      final deviceState = await device.connectionState.first;
      if (deviceState != BluetoothConnectionState.connected) {
        logger.w("Device not connected when attempting to discover services");
        return;
      }

      bool foundMainService = false;

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
              _cmdCharacteristic = characteristic;
              if (characteristic.properties.notify ||
                  characteristic.properties.indicate) {
                await _telemetrySub?.cancel();
                _telemetrySub = characteristic.onValueReceived.listen(
                  (value) {
                    final decoded = utf8.decode(value, allowMalformed: true);
                    logger.d("Received BLE Data: $decoded");
                    // Debug-only: first point a raw packet is received, before
                    // any F| chunk reassembly / D|/L| parsing below. Packet
                    // type (D/F/L) is included as the trace sub-tag when the
                    // packet carries one of the known prefixes; legacy
                    // (unprefixed) packets trace without a sub-tag.
                    // final rxSub = decoded.startsWith('D|')
                    //     ? 'D'
                    //     : decoded.startsWith('F|')
                    //     ? 'F'
                    //     : decoded.startsWith('L|')
                    //     ? 'L'
                    //     : null;
                    // pvcTrace("BLE_RX", decoded, sub: rxSub);

                    // ---- F| chunk reassembly (temporary debug) ----
                    // Wire format: F|<snapshotId>|<chunkIndex>/<totalChunks>|<payload>
                    if (decoded.startsWith('F|') && decoded.contains('|', 2)) {
                      final parts = decoded.split('|');
                      if (parts.length < 4) {
                        logger.w(
                          "[FCHUNK] Malformed F chunk (need 4+ parts): $decoded",
                        );
                        return;
                      }
                      // parts[0]="F", parts[1]=snapshotId, parts[2]="n/total", parts[3...]=payload

                      final snapId = int.tryParse(parts[1]);
                      final chunkHeader = parts[2];
                      final slashIdx = chunkHeader.indexOf('/');
                      if (slashIdx == -1) {
                        logger.w(
                          "[FCHUNK] Missing / in header part '${parts[2]}': $decoded",
                        );
                        return;
                      }
                      final idx = int.tryParse(
                        chunkHeader.substring(0, slashIdx),
                      );
                      final total = int.tryParse(
                        chunkHeader.substring(slashIdx + 1),
                      );

                      if (snapId == null || idx == null || total == null) {
                        logger.w("[FCHUNK] Bad header values: $decoded");
                        return;
                      }

                      // Payload is everything after the 3rd pipe
                      int payloadStart = 0;
                      for (int i = 0; i < 3; i++) {
                        payloadStart = decoded.indexOf('|', payloadStart) + 1;
                      }
                      final payload = decoded.substring(payloadStart);

                      // New snapshot started — discard any previous incomplete one
                      if (_fChunks.isEmpty || snapId != _fSnapshotId) {
                        _fChunks.clear();
                        _fSnapshotId = snapId;
                        _fExpectedTotal = total;
                        logger.i("[FCHUNK] New snapshot=$snapId total=$total");
                      }

                      _fChunks.add(payload);
                      logger.i(
                        "[FCHUNK] snapshot=$snapId index=$idx/$total "
                        "chunks=${_fChunks.length}",
                      );

                      // Check if all chunks received
                      if (_fChunks.length == _fExpectedTotal) {
                        final reconstructed = _fChunks.join();
                        logger.i("[FCHUNK] F snapshot complete: $snapId");
                        logger.i(
                          "[FCHUNK] F reconstructed length: ${reconstructed.length}",
                        );
                        logger.d(
                          "[FCHUNK] F reconstructed packet: $reconstructed",
                        );

                        // Parse the completed snapshot
                        final merged = MachineData.mergeFromPacket(
                          reconstructed,
                          state.machineData,
                        );
                        state = state.copyWith(
                          characteristicValue: reconstructed,
                          machineData: merged,
                        );
                        if (reconstructed.contains('TRANSITION:False')) {
                          setBusy(false);
                        }

                        // Clear buffer
                        _fChunks.clear();
                        _fExpectedTotal = 0;
                        _fSnapshotId = 0;
                        return; // Already parsed above
                      }

                      // More chunks expected — don't parse yet
                      return;
                    }

                    // ---- End F| chunk reassembly ----

                    final merged = MachineData.mergeFromPacket(
                      decoded,
                      state.machineData,
                    );
                    state = state.copyWith(
                      characteristicValue: decoded,
                      machineData: merged,
                    );
                    if (decoded.contains('TRANSITION:False')) {
                      setBusy(false);
                    }

                    // ---- Phase 2 instrumentation: timestamp transition edges ----
                    // Lets us measure the real client-visible latency:
                    //   command sent  ->  TRANSITION=True received  ->  TRANSITION=False received
                    if (decoded.contains('TRANSITION:True') ||
                        decoded.contains('TRANSITION:False')) {
                      final ts = _timestamp();
                      final label = decoded.contains('TRANSITION:True')
                          ? 'TRANSITION=True'
                          : 'TRANSITION=False';
                      final updated = [
                        ...state.serialLog,
                        "$ts RCV $label [$decoded]",
                      ];
                      updated.removeRange(0, max(0, updated.length - 500));
                      state = state.copyWith(serialLog: updated);
                    }
                  },
                  onError: (error) {
                    logger.e("Telemetry stream error: $error");
                  },
                );
                await characteristic.setNotifyValue(true);
                // Allow Android GATT stack to fully propagate notification enable
                await Future.delayed(const Duration(milliseconds: 50));
                logger.i(
                  "Subscribed to characteristic: ${characteristic.uuid}",
                );
                foundMainService = true;
                // Notifications are live now, so ask for a full snapshot. The
                // kit's connect-time F| was almost certainly emitted before
                // this point and dropped by the stack.
                await requestSync();
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

      // Only an actual miss is an error. This used to run unconditionally, so
      // every successful connect also raised "Service not found".
      if (!foundMainService) {
        state = state.copyWith(errorMessage: "Service not found - check logs");
      } else {
        state = state.copyWith(clearError: true);
      }
    } catch (e) {
      logger.e("Error discovering services", error: e);
    }
  }

  Future<bool> writeToCharacteristic(
    String data, {
    Duration busyTimeout = const Duration(seconds: 8),
  }) async {
    if (state.connectedDevice == null) {
      state = state.copyWith(errorMessage: "No device connected");
      return false;
    }

    if (state.isBusy) {
      logger.w("⚠️ Dropped command (busy): $data");
      return false;
    }

    setBusy(true, timeout: busyTimeout);

    bool ok = await _performWrite(data);
    if (!ok) {
      setBusy(false);
    }
    return ok;
  }

  /// Writes to the characteristic WITHOUT the busy lock and WITHOUT setting
  /// busy. Used for old-kit multi-part commands (mode + unit) so the second
  /// write isn't dropped while the first still holds the busy flag.
  Future<bool> writeRawToCharacteristic(String data) async {
    if (state.connectedDevice == null) {
      state = state.copyWith(errorMessage: "No device connected");
      return false;
    }
    return _performWrite(data);
  }

  Future<bool> _performWrite(String data) async {
    if (_cmdCharacteristic == null) {
      state = state.copyWith(errorMessage: "Characteristic not found");
      return false;
    }
    try {
      if (_cmdCharacteristic!.properties.write) {
        await _cmdCharacteristic!.write(data.codeUnits);
        // Debug-only: the actual characteristic-write boundary — fires for
        // every real BLE TX regardless of caller (writeToCharacteristic()/
        // writeRawToCharacteristic()), not just the UI button press.
        pvcTrace("BLE_TX", data);
        final ts = _timestamp();
        final updated = [...state.serialLog, "$ts TX: $data"];
        updated.removeRange(0, max(0, updated.length - 500));
        state = state.copyWith(clearError: true, serialLog: updated);
        return true;
      } else {
        logger.w(
          "Characteristic ${_cmdCharacteristic!.properties.write} $data is not writable",
        );
        state = state.copyWith(errorMessage: "Characteristic is not writable");
        return false;
      }
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
      if (_cmdCharacteristic == null) {
        state = state.copyWith(errorMessage: "Characteristic not found");
        return null;
      }

      if (_cmdCharacteristic!.properties.read) {
        List<int> value = await _cmdCharacteristic!.read();
        String result = String.fromCharCodes(value);
        state = state.copyWith(characteristicValue: result, clearError: true);
        return result;
      } else {
        state = state.copyWith(errorMessage: "Characteristic is not readable");
        return null;
      }
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
  //
  // Only one busy-guard safety timer is ever outstanding: any previous
  // timer is cancelled before a new one is created (or on clear), so a
  // stale timer from an earlier write can never fire after busy has since
  // been legitimately cleared and possibly re-set by a new operation.
  void setBusy(bool value, {Duration? timeout}) {
    _busyTimer?.cancel();
    _busyTimer = null;
    state = state.copyWith(isBusy: value);
    if (value) {
      // Safety timeout: auto-clear if hardware never responds. Default 8s;
      // mode changes (FUNCTION reboot) can take up to 10s, so callers pass a
      // longer timeout to avoid a spurious unlock while the PAM is still busy.
      final effective = timeout ?? const Duration(seconds: 8);
      _busyTimer = Timer(effective, () {
        if (state.isBusy) {
          logger.w("D| ⚠️ Busy guard timed out — forcing unlock");
          state = state.copyWith(isBusy: false);
        }
        _busyTimer = null;
      });
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// Modify a single field in MachineData by JSON key name.
  void modifyMachineData(String field, dynamic value) {
    state = state.copyWith(
      machineData: state.machineData.modifyField(field, value),
    );
  }
}

// Provider for BLE state management
final bleProvider = NotifierProvider<BleNotifier, BleState>(() {
  return BleNotifier();
});

// Stream provider for scan results
final scanResultsProvider = StreamProvider<List<ScanResult>>((ref) {
  return FlutterBluePlus.scanResults
      .handleError((Object error) {
        // Scan stream errors (e.g. SCAN_FAILED_ALREADY_STARTED left over from a
        // previous app session) are recovered by the scan screen. Swallow them
        // here so this provider stays alive instead of entering an error state.
      })
      .map(
        (results) =>
            results.where((r) => r.device.platformName.isNotEmpty).toList(),
      );
});

/// A provider that returns the merged MachineData from BLE state.
final machineDataProvider = Provider<MachineData>((ref) {
  final bleState = ref.watch(bleProvider);
  return bleState.machineData;
});
