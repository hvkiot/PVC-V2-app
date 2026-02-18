import 'package:json_annotation/json_annotation.dart';
import 'package:logger/logger.dart';

// This is required for the generator to work
part 'machine_data.g.dart';

@JsonSerializable()
class MachineData {
  @JsonKey(name: 'FUNC')
  final String func;

  @JsonKey(name: 'WA')
  final String inputA;

  @JsonKey(name: 'WB')
  final String inputB;

  @JsonKey(name: 'IA')
  final String coilA;

  @JsonKey(name: 'IB')
  final String coilB;

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
  final String coilACurrent;

  @JsonKey(name: 'CURRENT_B_STATUS')
  final String coilBCurrent;

  @JsonKey(name: 'CURRENT_STATUS')
  final String coilCurrent;

  MachineData({
    this.func = '0',
    this.inputA = '0.0',
    this.inputB = '0.0',
    this.coilA = '0.0',
    this.coilB = '0.0',
    this.mode = '0',
    this.ready = 'ALL OFF',
    this.pin15 = false,
    this.pin6 = false,
    this.enableB = false,
    this.coilACurrent = '0.0',
    this.coilBCurrent = '0.0',
    this.coilCurrent = '0.0',
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
    // Use dynamic here so we can put both Strings and Bools in the map
    final Map<String, dynamic> dataMap = {};

    try {
      final parts = cleanPacket.split(',');
      for (var part in parts) {
        final kv = part.split(':');
        if (kv.length == 2) {
          String key = kv[0];
          String value = kv[1];

          // Handle the Boolean Conversion manually
          if (key == 'PIN15' || key == 'PIN6') {
            dataMap[key] =
                value.toLowerCase() == 'true'; // Converts "True" -> true
          } else if (key == 'ENABLE_B') {
            dataMap[key] =
                value.toLowerCase() == 'true'; // Converts "True" -> true
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
