part of '../ble_command_controller.dart';

/// Param 08/15 plus PPWM/IPWM/ACC — ramp timing, current-loop, and the
/// PWM-duty/acceleration writes that sit next to them in the original file.
/// [writePpwm], [writeIpwm], and [writeAcceleration] are intentionally
/// retained even though no current Advanced Config parameter card calls
/// them (kept for controller-level parity/reuse since Phase 1 — do not
/// remove).
mixin _CurrentRampWrites {
  // Minimal abstract requirements from BleCommandController's own class
  // body, restated here only because Dart mixins can't use an `on`
  // constraint pointing back at the very class that mixes them in
  // (that would be a circular supertype declaration — see the file-banner
  // comment in ble_command_controller.dart). Satisfied concretely by
  // BleCommandController.execute()/._md; this mixin never implements
  // either itself.
  Future<bool> execute(
    List<String> commands, {
    bool isModeChange = false,
    bool showOverlay = true,
    void Function(int index, int total)? onProgress,
  });
  MachineData get _md;

  /// Param 08 — Ramp (accel/decel). Mode 195 uses the raw PAM quadrant
  /// syntax (AA:1..AA:4); mode 196 uses the per-channel UP/DOWN syntax
  /// (AA:UP/AA:DOWN for channel A, AB:UP/AB:DOWN for channel B).
  ///
  /// Only the quadrant(s) whose draft value differs from the MachineData
  /// baseline are sent. The ESP grouped RAMP parser only accepts a
  /// fixed-shape "RAMP:AUP:..:ADOWN:..:BUP:..:BDOWN:.." command with all
  /// four keys present (see commands.cpp's parseBleCommand()) — it does
  /// not support a partial/subset grouped form, so that single grouped
  /// command is only used when all four quadrants changed; otherwise the
  /// changed quadrants are sent individually via their existing single
  /// commands (still one execute() call, just a shorter command list).
  Future<bool> writeRamp({
    required String mode,
    required int aUp,
    required int aDown,
    required int bUp,
    required int bDown,
  }) {
    final aUpChanged = aUp != _md.expConfig.rampAaUp;
    final aDownChanged = aDown != _md.expConfig.rampAaDown;
    final bUpChanged = bUp != _md.expConfig.rampAbUp;
    final bDownChanged = bDown != _md.expConfig.rampAbDown;
    final changedCount = [
      aUpChanged,
      aDownChanged,
      bUpChanged,
      bDownChanged,
    ].where((c) => c).length;

    if (changedCount == 0) return execute(const []);

    if (mode == '196') {
      if (changedCount == 4) {
        return execute(['RAMP:AUP:$aUp:ADOWN:$aDown:BUP:$bUp:BDOWN:$bDown']);
      }
      final cmds = <String>[
        if (aUpChanged) 'AA:UP:$aUp',
        if (aDownChanged) 'AA:DOWN:$aDown',
        if (bUpChanged) 'AB:UP:$bUp',
        if (bDownChanged) 'AB:DOWN:$bDown',
      ];
      return execute(cmds);
    }
    // Mode 195 uses the distinct quadrant-number PAM addressing (AA:1..4)
    // — the grouped RAMP command always writes the 196-style AA:UP/DOWN,
    // AB:UP/DOWN forms on the ESP side, so it is never used here; only the
    // changed quadrants are sent, via the existing per-quadrant commands.
    final cmds = <String>[
      if (aUpChanged) 'AA:1:$aUp',
      if (aDownChanged) 'AA:2:$aDown',
      if (bUpChanged) 'AA:3:$bUp',
      if (bDownChanged) 'AA:4:$bDown',
    ];
    return execute(cmds);
  }

  /// Not yet exposed by any Advanced Config parameter card (no '05'-style
  /// dropdown entry maps to it). Kept for controller-level parity/reuse.
  /// commands.cpp has no tracked CMD_SET_PARAM entry for PPWM, so this
  /// keeps the exact raw fire-and-forget shape the old bulk save used.
  Future<bool> writePpwm({required String mode, int? global, int? a, int? b}) {
    if (mode == '196') {
      return execute(['PPWM:A $a', 'PPWM:B $b']);
    }
    return execute(['PPWM $global']);
  }

  /// Same status as [writePpwm] — no dropdown entry selects it yet.
  Future<bool> writeIpwm({required String mode, int? global, int? a, int? b}) {
    if (mode == '196') {
      return execute(['IPWM:A $a', 'IPWM:B $b']);
    }
    return execute(['IPWM $global']);
  }

  /// Param 15 — Current. Reuses Basic Config's existing legacy
  /// CUR/CURA/CURB format (tracked via CMD_SET_CURRENT on the firmware).
  Future<bool> writeCurrent({
    required String mode,
    int? single,
    int? a,
    int? b,
  }) {
    if (mode == '196') {
      final aChanged = a != null && a != _md.coilACurrent.round();
      final bChanged = b != null && b != _md.coilBCurrent.round();
      if (aChanged && bChanged) {
        return execute(['CUR196:A:$a:B:$b']);
      } else if (aChanged) {
        return execute(['CURA:$a:196']);
      } else if (bChanged) {
        return execute(['CURB:$b:196']);
      }
      return execute(const []);
    }
    return execute(['CUR:$single:195']);
  }

  /// Not yet exposed by any Advanced Config parameter card. Kept for
  /// controller-level parity; raw fire-and-forget, same as the old bulk
  /// save's 'ACC ON'/'ACC OFF'.
  Future<bool> writeAcceleration(bool value) {
    return execute(['ACC ${value ? "ON" : "OFF"}']);
  }
}
