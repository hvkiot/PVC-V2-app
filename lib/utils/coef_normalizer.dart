/// Normalizes a raw PAM AIN coefficient-type token to the app's editable
/// V/C representation. Confirmed hardware behavior: PAM readback does not
/// echo the token the app writes — it reports "U" for voltage and "I" for
/// current (write V -> readback U; write C -> readback I). "V"/"U" -> "V";
/// "C"/"I" -> "C"; anything else (e.g. "None", empty) -> "V" as a safe
/// editable default.
///
/// Single shared implementation of a boundary that used to be duplicated
/// verbatim (same switch expression) in three places — `pam_data_screen.dart`,
/// `ble_command_controller.dart`, and `advanced_config_draft_provider.dart`
/// each had their own private `_normalizeCoefType`, all doc-commented as
/// "must stay identical" to each other. Consolidated 2026-09 (Phase 1
/// cleanup) after confirming byte-for-byte identical logic in all three —
/// this is the coefficient *type* boundary only (Parameter 07's editable
/// `V`/`C` selector, `AIN_A/B_COEF_TYPE` on the wire); it does not touch and
/// must never be merged with the separate live AIN mode concept
/// (`MachineData.mode`, the root/live `AINA`/`AINB` V/C reading shown on
/// Home) — those are deliberately distinct, see the call sites' own
/// surrounding comments.
///
/// Also mirrored in firmware as `normalizeCoefType()` in
/// `PVC_V2_ESP32.ino` (same boundary, ESP side) — not something this file
/// can share code with, kept here only as a cross-reference note.
String normalizeCoefType(String raw) => switch (raw) {
  'V' || 'U' => 'V',
  'C' || 'I' => 'C',
  _ => 'V',
};
