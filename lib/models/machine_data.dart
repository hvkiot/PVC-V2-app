import 'package:json_annotation/json_annotation.dart';
import 'package:logger/logger.dart';

// This is required for the generator to work
part 'machine_data.g.dart';

double _parseDouble(String? value) {
  return double.tryParse(value ?? '') ?? 0.0;
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

  @JsonKey(name: 'ENABLE_B')
  final bool enableB;

  @JsonKey(name: 'CURRENT_A_STATUS')
  final double coilACurrent;

  @JsonKey(name: 'CURRENT_B_STATUS')
  final double coilBCurrent;

  @JsonKey(name: 'CURRENT_STATUS')
  final double coilCurrent;

  MachineData({
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
  });

  // Connect to the generated factory
  factory MachineData.fromJson(Map<String, dynamic> json) =>
      _$MachineDataFromJson(json);

  // Connect to the generated generator
  Map<String, dynamic> toJson() => _$MachineDataToJson(this);

  /// Modified factory to keep your CSV-style parsing logic
  /// while utilizing the new JSON structure.
  factory MachineData.fromPacket(String packet) {
    final cleanPacket = packet.trim();
    // Use dynamic here so we can put both Strings and Bools/Doubles in the map
    final Map<String, dynamic> dataMap = {};

    try {
      final parts = cleanPacket.split(',');
      for (var part in parts) {
        final kv = part.split(':');
        if (kv.length == 2) {
          String key = kv[0];
          String value = kv[1];

          // Handle Boolean Conversion
          if (key == 'PIN15' || key == 'PIN6' || key == 'ENABLE_B') {
            dataMap[key] = value.toLowerCase() == 'true';
          }
          // Handle Numeric Conversion (Double)
          else if (key == 'WA' ||
              key == 'WB' ||
              key == 'IA' ||
              key == 'IB' ||
              key == 'CURRENT_A_STATUS' ||
              key == 'CURRENT_B_STATUS' ||
              key == 'CURRENT_STATUS') {
            dataMap[key] = _parseDouble(value);
          } else {
            dataMap[key] = value;
          }
        }
      }
      return MachineData.fromJson(dataMap);
    } catch (e) {
      Logger().e("Parsing error: $e");
      return MachineData();
    }
  }
}
