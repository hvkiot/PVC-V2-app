// lib/providers/ota_provider.dart
// ============================================================
// OTA Provider — Riverpod StateNotifier
// Handles firmware upload to ESP32 via BLE OTA service
// Uses flutter_blue_plus ^2.1.0
// ============================================================
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

// ---- OTA BLE UUIDs (must match ESP32 ble_server.cpp) ----
const String _otaServiceUuid = "12345678-1234-1234-1234-1234567890ab";
const String _otaControlUuid = "12345678-1234-1234-1234-1234567890ac";
const String _otaDataUuid = "12345678-1234-1234-1234-1234567890ad";

// Chunk size: 240 bytes is safe for MTU 247 (247 - 3 ATT header - 4 L2CAP)
const int _chunkSize = 244;

// ---- OTA State ----
enum OtaStatus {
  idle, // waiting for user action
  picking, // file picker open
  starting, // sending START command
  uploading, // sending chunks
  finalizing, // sending END command
  success, // done, device rebooting
  error, // something went wrong
}

class OtaState {
  final OtaStatus status;
  final double progress; // 0.0 to 1.0
  final String message;
  final String? fileName;
  final int? fileSize;

  const OtaState({
    this.status = OtaStatus.idle,
    this.progress = 0.0,
    this.message = "Ready to update firmware",
    this.fileName,
    this.fileSize,
  });

  OtaState copyWith({
    OtaStatus? status,
    double? progress,
    String? message,
    String? fileName,
    int? fileSize,
  }) {
    return OtaState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  bool get isRunning =>
      status == OtaStatus.starting ||
      status == OtaStatus.uploading ||
      status == OtaStatus.finalizing;
}

// ---- OTA Notifier ----
class OtaNotifier extends StateNotifier<OtaState> {
  final Logger _log = Logger();

  OtaNotifier() : super(const OtaState());

  // ---- Get OTA characteristics from connected device ----
  Future<({BluetoothCharacteristic control, BluetoothCharacteristic data})?>
  _getOtaChars(BluetoothDevice device) async {
    try {
      // Discover services if not already discovered
      List<BluetoothService> services = device.servicesList;
      if (services.isEmpty) {
        services = await device.discoverServices();
      }

      // Find OTA service
      final otaService = services
          .where(
            (s) => s.serviceUuid.toString().toLowerCase() == _otaServiceUuid,
          )
          .firstOrNull;

      if (otaService == null) {
        _log.e("[OTA] OTA service not found on device");
        return null;
      }

      // Find control characteristic
      final controlChar = otaService.characteristics
          .where(
            (c) =>
                c.characteristicUuid.toString().toLowerCase() ==
                _otaControlUuid,
          )
          .firstOrNull;

      // Find data characteristic
      final dataChar = otaService.characteristics
          .where(
            (c) =>
                c.characteristicUuid.toString().toLowerCase() == _otaDataUuid,
          )
          .firstOrNull;

      if (controlChar == null || dataChar == null) {
        _log.e("[OTA] OTA characteristics not found");
        return null;
      }

      return (control: controlChar, data: dataChar);
    } catch (e) {
      _log.e("[OTA] Failed to get OTA characteristics: $e");
      return null;
    }
  }

  // ---- Main OTA upload function ----
  Future<void> startOta(BluetoothDevice device) async {
    // Step 1: Pick .bin file
    state = state.copyWith(
      status: OtaStatus.picking,
      message: "Select firmware .bin file...",
    );

    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
        allowMultiple: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: OtaStatus.error,
        message: "File picker error: $e",
      );
      return;
    }

    if (result == null || result.files.single.path == null) {
      // User cancelled
      state = state.copyWith(
        status: OtaStatus.idle,
        message: "Ready to update firmware",
      );
      return;
    }

    final filePath = result.files.single.path!;
    final fileName = result.files.single.name;
    final file = File(filePath);

    // Step 2: Read file bytes
    Uint8List fileBytes;
    try {
      fileBytes = await file.readAsBytes();
    } catch (e) {
      state = state.copyWith(
        status: OtaStatus.error,
        message: "Failed to read file: $e",
      );
      return;
    }

    final fileSize = fileBytes.length;
    _log.i("[OTA] File: $fileName, Size: $fileSize bytes");

    state = state.copyWith(
      status: OtaStatus.starting,
      progress: 0.0,
      message: "Connecting to OTA service...",
      fileName: fileName,
      fileSize: fileSize,
    );

    // Step 3: Get OTA characteristics
    final chars = await _getOtaChars(device);
    if (chars == null) {
      state = state.copyWith(
        status: OtaStatus.error,
        message:
            "OTA service not found on device.\nMake sure the latest firmware is installed.",
      );
      return;
    }

    // Step 4: Send START command
    try {
      final startCmd = "START:$fileSize";
      _log.i("[OTA] Sending: $startCmd");

      await chars.control.write(startCmd.codeUnits, withoutResponse: false);

      // Give ESP32 time to initialize flash writer
      await Future.delayed(const Duration(milliseconds: 500));

      state = state.copyWith(
        status: OtaStatus.uploading,
        message: "Uploading firmware...",
      );
    } catch (e) {
      state = state.copyWith(
        status: OtaStatus.error,
        message: "Failed to start OTA session: $e",
      );
      return;
    }

    // Step 5: Send firmware in chunks
    int bytesSent = 0;
    try {
      while (bytesSent < fileSize) {
        final end = (bytesSent + _chunkSize < fileSize)
            ? bytesSent + _chunkSize
            : fileSize;

        final chunk = fileBytes.sublist(bytesSent, end);

        await chars.data.write(
          chunk,
          withoutResponse: true, // no ACK wait = faster
        );

        bytesSent += chunk.length;
        final progress = bytesSent / fileSize;
        final percent = (progress * 100).toStringAsFixed(1);

        state = state.copyWith(
          progress: progress,
          message: "Uploading: $percent% ($bytesSent / $fileSize bytes)",
        );

        // Small delay between chunks to avoid BLE congestion
        await Future.delayed(const Duration(milliseconds: 5));
      }
    } catch (e) {
      state = state.copyWith(
        status: OtaStatus.error,
        message: "Upload failed at $bytesSent/$fileSize bytes: $e",
      );
      return;
    }

    // Step 6: Send END command
    state = state.copyWith(
      status: OtaStatus.finalizing,
      progress: 1.0,
      message: "Finalizing firmware...",
    );

    try {
      await chars.control.write("END".codeUnits, withoutResponse: false);
    } catch (e) {
      state = state.copyWith(
        status: OtaStatus.error,
        message: "Failed to finalize OTA: $e",
      );
      return;
    }

    // Step 7: Success
    state = state.copyWith(
      status: OtaStatus.success,
      message: "✓ Firmware updated!\nDevice is rebooting...",
    );

    _log.i("[OTA] Complete! Device rebooting.");
  }

  // Reset state back to idle (e.g. after error or success)
  void reset() {
    state = const OtaState();
  }
}

// ---- Riverpod Provider ----
final otaProvider = StateNotifierProvider<OtaNotifier, OtaState>(
  (ref) => OtaNotifier(),
);
