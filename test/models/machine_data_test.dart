import 'package:flutter_test/flutter_test.dart';
import 'package:pvc_v2/models/machine_data.dart';

void main() {
  const validPacket =
      'FUNC:196,WA:1.25,WB:-2.5,IA:875,IB:925,MODE:C,READY:A + B ACTIVE,'
      'PIN15:True,PIN6:False,ENABLE_B:True,CURRENT_A_STATUS:870.5,'
      'CURRENT_B_STATUS:920.25,CURRENT_STATUS:1790.75,'
      'FIRMWARE_VERSION:2.0.3,ADAPTER_VOLTAGE:24.6V,TRANSITION:True,'
      'PAM_CONNECTED:True';

  group('MachineData.fromPacket (legacy)', () {
    test('parses a complete ESP32 telemetry packet', () {
      final data = MachineData.fromPacket(validPacket);

      expect(data.func, '196');
      expect(data.inputA, 1.25);
      expect(data.inputB, -2.5);
      expect(data.coilA, 875.0);
      expect(data.coilB, 925.0);
      expect(data.mode, 'C');
      expect(data.ready, 'A + B ACTIVE');
      expect(data.pin15, isTrue);
      expect(data.pin6, isFalse);
      expect(data.enableB, isTrue);
      expect(data.coilACurrent, 870.5);
      expect(data.coilBCurrent, 920.25);
      expect(data.coilCurrent, 1790.75);
      expect(data.firmwareVersion, '2.0.3');
      expect(data.voltage, '24.6V');
      expect(data.transition, isTrue);
      expect(data.pamConnected, isTrue);
    });

    test('parses PAM_CONNECTED:True', () {
      final data = MachineData.fromPacket('PAM_CONNECTED:True');

      expect(data.pamConnected, isTrue);
    });

    test('parses PAM_CONNECTED:False', () {
      final data = MachineData.fromPacket('PAM_CONNECTED:False');

      expect(data.pamConnected, isFalse);
    });

    test('uses production defaults when optional fields are absent', () {
      expect(
        () => MachineData.fromPacket('FUNC:195,MODE:V'),
        returnsNormally,
      );

      final data = MachineData.fromPacket('FUNC:195,MODE:V');
      expect(data.func, '195');
      expect(data.mode, 'V');
      expect(data.ready, 'ALL OFF');
      expect(data.pamConnected, isFalse);
      expect(data.inputA, 0.0);
    });

    test('preserves malformed numeric fallback values', () {
      final data = MachineData.fromPacket(
        'WA:not-a-number,WB:,IA:bad,IB:--,CURRENT_A_STATUS:nope,'
        'CURRENT_B_STATUS:broken,CURRENT_STATUS:invalid',
      );

      expect(data.inputA, 0.0);
      expect(data.inputB, 0.0);
      expect(data.coilA, 0.0);
      expect(data.coilB, 0.0);
      expect(data.coilACurrent, 0.0);
      expect(data.coilBCurrent, 0.0);
      expect(data.coilCurrent, 0.0);
    });
  });

  group('MachineData.mergeFromPacket (L/D/F)', () {
    const fullSnapshot =
        'F|FUNC:196,WA:1.25,WB:-2.5,IA:875,IB:925,MODE:C,READY:A + B ACTIVE,'
        'PIN15:True,PIN6:False,ENABLE_B:True,CURRENT_A_STATUS:870.5,'
        'CURRENT_B_STATUS:920.25,CURRENT_STATUS:1790.75,'
        'FIRMWARE_VERSION:2.0.3,ADAPTER_VOLTAGE:24.6V,TRANSITION:True,'
        'PAM_CONNECTED:True';

    const liveUpdate = 'L|WA:2.5,WB:3.5,IA:900,IB:950,READY:A ACTIVE,PIN15:False,PIN6:True';

    const deltaUpdate = 'D|WA:5.0,MODE:V,READY:B ACTIVE';

    const multiDelta = 'D|FUNC:195,WA:1.0,WB:2.0,IA:800,IB:850';

    test('F| full snapshot replaces complete state', () {
      final data = MachineData.mergeFromPacket(fullSnapshot, MachineData());

      expect(data.func, '196');
      expect(data.inputA, 1.25);
      expect(data.inputB, -2.5);
      expect(data.coilA, 875.0);
      expect(data.coilB, 925.0);
      expect(data.mode, 'C');
      expect(data.ready, 'A + B ACTIVE');
      expect(data.pin15, isTrue);
      expect(data.pin6, isFalse);
      expect(data.enableB, isTrue);
      expect(data.coilACurrent, 870.5);
      expect(data.coilBCurrent, 920.25);
      expect(data.coilCurrent, 1790.75);
      expect(data.firmwareVersion, '2.0.3');
      expect(data.voltage, '24.6V');
      expect(data.transition, isTrue);
      expect(data.pamConnected, isTrue);
    });

    test('F| ignores previous state completely', () {
      final previous = MachineData.fromPacket(
        'FUNC:195,WA:999,WB:999,MODE:V,READY:ALL OFF,PIN15:False,PIN6:False',
      );
      final data = MachineData.mergeFromPacket(fullSnapshot, previous);

      expect(data.func, '196');
      expect(data.inputA, 1.25);
      expect(data.inputB, -2.5);
      expect(data.mode, 'C');
    });

    test('L| live update merges only specified fields', () {
      final base = MachineData.fromPacket(
        'FUNC:196,WA:1.0,WB:1.0,IA:100,IB:200,MODE:C,READY:ALL OFF,'
        'PIN15:True,PIN6:True,ENABLE_B:False,'
        'FIRMWARE_VERSION:1.0.0,ADAPTER_VOLTAGE:24V,TRANSITION:False,'
        'PAM_CONNECTED:False',
      );
      final data = MachineData.mergeFromPacket(liveUpdate, base);

      // Updated fields from L|
      expect(data.inputA, 2.5);
      expect(data.inputB, 3.5);
      expect(data.coilA, 900.0);
      expect(data.coilB, 950.0);
      expect(data.ready, 'A ACTIVE');
      expect(data.pin15, isFalse);
      expect(data.pin6, isTrue);

      // Unchanged fields preserved from base
      expect(data.func, '196');
      expect(data.mode, 'C');
      expect(data.enableB, isFalse);
      expect(data.firmwareVersion, '1.0.0');
      expect(data.voltage, '24V');
      expect(data.transition, isFalse);
      expect(data.pamConnected, isFalse);
      expect(data.coilACurrent, 0.0);
      expect(data.coilBCurrent, 0.0);
      expect(data.coilCurrent, 0.0);
    });

    test('D| delta update merges only present fields', () {
      final base = MachineData.fromPacket(
        'FUNC:196,WA:1.0,WB:1.0,IA:100,IB:200,MODE:C,READY:ALL OFF,'
        'PIN15:True,PIN6:True,ENABLE_B:False,'
        'FIRMWARE_VERSION:1.0.0,ADAPTER_VOLTAGE:24V,TRANSITION:False,'
        'PAM_CONNECTED:False',
      );
      final data = MachineData.mergeFromPacket(deltaUpdate, base);

      // Updated fields from D|
      expect(data.inputA, 5.0);
      expect(data.mode, 'V');
      expect(data.ready, 'B ACTIVE');

      // Unchanged fields preserved
      expect(data.func, '196');
      expect(data.inputB, 1.0);
      expect(data.coilA, 100.0);
      expect(data.coilB, 200.0);
      expect(data.pin15, isTrue);
      expect(data.pin6, isTrue);
      expect(data.enableB, isFalse);
    });

    test('D| multiple delta fields updates all present', () {
      final base = MachineData.fromPacket(
        'FUNC:196,WA:1.0,WB:1.0,IA:100,IB:200,MODE:C,READY:ALL OFF,'
        'PIN15:True,PIN6:True,ENABLE_B:False,'
        'FIRMWARE_VERSION:1.0.0,ADAPTER_VOLTAGE:24V,TRANSITION:False,'
        'PAM_CONNECTED:False',
      );
      final data = MachineData.mergeFromPacket(multiDelta, base);

      expect(data.func, '195');
      expect(data.inputA, 1.0);
      expect(data.inputB, 2.0);
      expect(data.coilA, 800.0);
      expect(data.coilB, 850.0);
      expect(data.mode, 'C');
      expect(data.ready, 'ALL OFF');
      expect(data.pin15, isTrue);
      expect(data.pin6, isTrue);
    });

    test('L| before F| works correctly', () {
      // Start with default state
      var data = MachineData.mergeFromPacket(liveUpdate, MachineData());
      expect(data.inputA, 2.5);
      expect(data.func, '0'); // default

      // Then receive F| full snapshot
      data = MachineData.mergeFromPacket(fullSnapshot, data);
      expect(data.func, '196');
      expect(data.inputA, 1.25);
      expect(data.inputB, -2.5);
      expect(data.coilA, 875.0);
      expect(data.coilB, 925.0);
    });

    test('D| before F| works correctly', () {
      var data = MachineData.mergeFromPacket(deltaUpdate, MachineData());
      expect(data.inputA, 5.0);
      expect(data.mode, 'V');
      expect(data.ready, 'B ACTIVE');

      data = MachineData.mergeFromPacket(fullSnapshot, data);
      expect(data.func, '196');
      expect(data.mode, 'C');
      expect(data.inputA, 1.25);
    });

    test('empty packet returns current state unchanged', () {
      final base = MachineData.fromPacket('WA:5.0,FUNC:195');
      final data = MachineData.mergeFromPacket('', base);
      expect(data.inputA, 5.0);
      expect(data.func, '195');
    });

    test('malformed packet returns current state unchanged', () {
      final base = MachineData.fromPacket('WA:5.0,FUNC:195');
      final data = MachineData.mergeFromPacket('not a valid packet', base);
      expect(data.inputA, 5.0);
      expect(data.func, '195');
    });

    test('unknown fields are ignored safely', () {
      final base = MachineData.fromPacket('FUNC:196,WA:1.0');
      final data = MachineData.mergeFromPacket('L|UNKNOWN_FIELD:123,WA:2.0', base);
      expect(data.inputA, 2.0);
      expect(data.func, '196');
    });

    test('legacy packet without prefix still works via mergeFromPacket', () {
      final data = MachineData.mergeFromPacket(validPacket, MachineData());
      expect(data.func, '196');
      expect(data.inputA, 1.25);
      expect(data.pamConnected, isTrue);
    });

    test('unknown prefix treated as legacy', () {
      final data = MachineData.mergeFromPacket('X|WA:7.0,FUNC:195', MachineData());
      expect(data.inputA, 7.0);
      expect(data.func, '195');
    });

    test('ENABLED_B field from firmware is parsed correctly', () {
      final data = MachineData.mergeFromPacket(
        'F|WA:1.0,ENABLED_B:True,MODE:C',
        MachineData(),
      );
      expect(data.enableB, isTrue);
    });

    test('ENABLE_B legacy field still works', () {
      final data = MachineData.fromPacket('ENABLE_B:True,FUNC:196');
      expect(data.enableB, isTrue);
    });
  });
}
