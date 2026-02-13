import 'package:logger/logger.dart';

class MachineData {
  final String func;
  final String inputA; // WA
  final String inputB; // WB
  final String coilA; // IA
  final String coilB; // IB
  final String mode;

  MachineData({
    this.func = '0',
    this.inputA = '0.0',
    this.inputB = '0.0',
    this.coilA = '0.0',
    this.coilB = '0.0',
    this.mode = '0',
  });

  // Factory constructor to parse the CSV-style string from BLE
  factory MachineData.fromPacket(String packet) {
    // Remove newline and split by comma
    final cleanPacket = packet.trim();
    final Map<String, String> dataMap = {};

    try {
      final parts = cleanPacket.split(',');
      for (var part in parts) {
        final kv = part.split(':');
        if (kv.length == 2) {
          dataMap[kv[0]] = kv[1];
        }
      }

      return MachineData(
        func: dataMap['FUNC'] ?? '0',
        inputA: dataMap['WA'] ?? '0.0',
        inputB: dataMap['WB'] ?? '0.0',
        coilA: dataMap['IA'] ?? '0.0',
        coilB: dataMap['IB'] ?? '0.0',
        mode: dataMap['MODE'] ?? '0',
      );
    } catch (e) {
      Logger().e("Parsing error: $e");
      return MachineData(); // Return default values on error
    }
  }
}
