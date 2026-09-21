part of '../ble_command_controller.dart';

/// Param 01/02/03/04/11 — single-value writes with no per-channel diffing:
/// each method builds one command straight from its argument and sends it
/// via [BleCommandController.execute]. No comparison against the current
/// [MachineData] baseline (unlike the diffed writes in
/// `diffed_parameter_writes.dart`) — these params are always sent as given.
mixin _SimpleParameterWrites {
  // Minimal abstract requirement from BleCommandController's own class
  // body, restated here only because Dart mixins can't use an `on`
  // constraint pointing back at the very class that mixes them in
  // (that would be a circular supertype declaration — see the file-banner
  // comment in ble_command_controller.dart). Satisfied concretely by
  // BleCommandController.execute(); this mixin never implements it itself.
  Future<bool> execute(
    List<String> commands, {
    bool isModeChange = false,
    bool showOverlay = true,
    void Function(int index, int total)? onProgress,
  });

  /// Param 01 — Function (mode 195/196).
  /// Sends the bare mode command only (no unit/current suffix). This is
  /// the existing legacy CMD_CHANGE_MODE path: the firmware falls back to
  /// gState.lastAinUnit for the AIN unit and resets currents to PAM
  /// defaults — exactly what already happens whenever a bare "195"/"196"
  /// is sent, so Function stays isolated from AIN/CURRENT.
  Future<bool> writeFunction(String mode) {
    return execute([mode], isModeChange: true);
  }

  /// Param 02 — SENS ('ON' | 'OFF' | 'AUTO').
  Future<bool> writeSens(String value) {
    return execute(['SENS:$value']);
  }

  /// Param 03 — CC Mode.
  Future<bool> writeCcMode(bool value) {
    return execute(['CCMODE:${value ? "ON" : "OFF"}']);
  }

  /// Param 04 — Enable-B (mode 196 only).
  Future<bool> writeEnableB(bool value) {
    return execute(['ENABLE_B:${value ? "ON" : "OFF"}']);
  }

  /// Param 11 — Trigger.
  Future<bool> writeTrigger(int value) {
    return execute(['TRIGGER:$value']);
  }
}
