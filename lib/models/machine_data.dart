import 'package:json_annotation/json_annotation.dart';
import 'package:logger/logger.dart';

// This is required for the generator to work
part 'machine_data.g.dart';

double _parseDouble(String? value) {
  return double.tryParse(value ?? '') ?? 0.0;
}

/// Parses a key:value pair and adds to dataMap with proper type conversion.
/// Returns true if parsed successfully, false otherwise.
bool _parseKeyValue(String key, String value, Map<String, dynamic> dataMap) {
  // Handle Boolean fields
  if (key == 'PIN15' ||
      key == 'PIN6' ||
      key == 'ENABLED_B' ||
      key == 'ENABLE_B' ||
      key == 'TRANSITION' ||
      key == 'PAM_CONNECTED') {
    dataMap[_mapKey(key)] = value.toLowerCase() == 'true';
    return true;
  }
  // Handle Numeric fields (Double)
  if (key == 'WA' ||
      key == 'WB' ||
      key == 'IA' ||
      key == 'IB' ||
      key == 'CURRENT_A' ||
      key == 'CURRENT_B' ||
      key == 'CURRENT_S' ||
      // Long-form legacy aliases for the current/stage values
      key == 'CURRENT_A_STATUS' ||
      key == 'CURRENT_B_STATUS' ||
      key == 'CURRENT_STATUS') {
    dataMap[_mapKey(key)] = _parseDouble(value);
    return true;
  }
  // Handle String fields
  else if (key == 'FUNC' ||
      key == 'MODE' ||
      key == 'READY' ||
      key == 'FIRMWARE_VERSION' ||
      key == 'ADAPTER_VOLTAGE') {
    dataMap[key] = value;
    return true;
  }
  // Unknown field - ignore safely
  return false;
}

/// Maps long-form legacy ESP32 keys to the canonical abbreviate JSON key.
String _mapKey(String key) {
  return switch (key) {
    'CURRENT_A_STATUS' => 'CURRENT_A',
    'CURRENT_B_STATUS' => 'CURRENT_B',
    'CURRENT_STATUS' => 'CURRENT_S',
    'ENABLE_B' => 'ENABLED_B',
    _ => key,
  };
}

@JsonSerializable()
class MachineData {
  @JsonKey(name: 'FUNC')
  final String func;

  @JsonKey(name: 'WA')
  final double inputA;

  @JsonKey(name: 'WB')
  final double inputB;

  @JsonKey(name: 'IA')
  final double coilA;

  @JsonKey(name: 'IB')
  final double coilB;

  @JsonKey(name: 'MODE')
  final String mode;

  @JsonKey(name: 'READY')
  final String ready;

  @JsonKey(name: 'PIN15')
  final bool pin15;

  @JsonKey(name: 'PIN6')
  final bool pin6;

  @JsonKey(name: 'ENABLED_B')
  final bool enableB;

  @JsonKey(name: 'CURRENT_A')
  final double coilACurrent;

  @JsonKey(name: 'CURRENT_B')
  final double coilBCurrent;

  @JsonKey(name: 'CURRENT_S')
  final double coilCurrent;

  @JsonKey(name: 'FIRMWARE_VERSION')
  final String firmwareVersion;

  @JsonKey(name: 'ADAPTER_VOLTAGE')
  final String voltage;

  @JsonKey(name: 'TRANSITION')
  final bool transition;

  @JsonKey(name: 'PAM_CONNECTED')
  final bool pamConnected;

  const MachineData({
    this.func = '0',
    this.inputA = 0.0,
    this.inputB = 0.0,
    this.coilA = 0.0,
    this.coilB = 0.0,
    this.mode = '0',
    this.ready = 'ALL OFF',
    this.pin15 = false,
    this.pin6 = false,
    this.enableB = false,
    this.coilACurrent = 0.0,
    this.coilBCurrent = 0.0,
    this.coilCurrent = 0.0,
    this.firmwareVersion = '0.0.0',
    this.voltage = '24V',
    this.transition = false,
    this.pamConnected = false,
  });

  // Connect to the generated factory
  factory MachineData.fromJson(Map<String, dynamic> json) =>
      _$MachineDataFromJson(json);

  // Connect to the generated generator
  Map<String, dynamic> toJson() => _$MachineDataToJson(this);

  /// Modified factory to keep your CSV-style parsing logic
  /// while utilizing the new JSON structure.
  factory MachineData.fromPacket(String packet) {
    return _parsePacketInternal(packet.trim(), null);
  }

  /// Parses a telemetry packet and merges into [current] state.
  /// Supports L| (live), D| (delta), F| (full snapshot), and legacy (no prefix).
  /// Returns the merged [MachineData] or [current] if packet is empty/malformed.
  static MachineData mergeFromPacket(String packet, MachineData current) {
    final cleanPacket = packet.trim();
    if (cleanPacket.isEmpty) return current;
    return _parsePacketInternal(cleanPacket, current);
  }

  static MachineData _parsePacketInternal(
    String cleanPacket,
    MachineData? current,
  ) {
    // Detect prefix
    String payload;
    String prefix = '';
    if (cleanPacket.startsWith('L|') ||
        cleanPacket.startsWith('D|') ||
        cleanPacket.startsWith('F|')) {
      prefix = cleanPacket.substring(0, 2);
      payload = cleanPacket.substring(2);
    } else if (cleanPacket.length >= 2 && cleanPacket[1] == '|') {
      // Unknown single-char prefix (e.g., X|) - strip it and treat as legacy
      payload = cleanPacket.substring(2);
    } else {
      // Legacy packet - full parse
      payload = cleanPacket;
    }

    // F| full snapshot replaces everything - ignore current
    final base = (prefix == 'F|') ? MachineData() : (current ?? MachineData());

    final Map<String, dynamic> dataMap = base.toJson();

    try {
      final parts = payload.split(',');
      for (var part in parts) {
        final kv = part.split(':');
        if (kv.length == 2) {
          String key = kv[0];
          String value = kv[1];
          // Use shared parser; unknown fields ignored
          _parseKeyValue(key, value, dataMap);
        }
      }
      return MachineData.fromJson(dataMap);
    } catch (e) {
      Logger().e("Parsing error: $e");
      return base;
    }
  }
}
