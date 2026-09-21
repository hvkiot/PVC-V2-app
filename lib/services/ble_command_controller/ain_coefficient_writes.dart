part of '../ble_command_controller.dart';

/// Param 07 — AIN / coefficient-type writes. Kept as its own mixin: this is
/// the only write helper that reads the shared [normalizeCoefType] (from
/// `utils/coef_normalizer.dart`, imported once in the library root) to diff
/// the PAM-readback coefficient-type token against the editable V/C value.
mixin _AinCoefficientWrites {
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

  /// Param 07 — AIN. [channel]/[a]/[b]/[c]/[type] describe channel A (or
  /// the only channel, in mode 195). Passing the optional [bA]/[bB]/[bC]/
  /// [bType] values as well produces the grouped mode-196 transaction —
  /// ONE tracked CMD_SET_PARAM_GROUP command ("AIN196:A:...:B:...") that
  /// writes+reads back both channels in a single ESP-side transaction.
  /// Without them, this keeps the exact original single-channel raw
  /// "AIN:< channel> <a> <b> < c> < type>" CMD_FORWARD_RAW passthrough
  /// (untracked, fire-and-forget) — unchanged for any existing caller that
  /// still invokes this per channel.
  Future<bool> writeAIN({
    required String channel,
    required int a,
    required int b,
    required int c,
    required String type,
    int? bA,
    int? bB,
    int? bC,
    String? bType,
  }) {
    if (bA != null && bB != null && bC != null && bType != null) {
      // Dual-channel call: diff each channel independently against the
      // MachineData baseline — neither changed → no command, one changed
      // → that channel's existing single raw command, both changed → one
      // grouped AIN196 command.
      //
      // Type baseline uses ainACoefType/ainBCoefType (Parameter 07's
      // editable coefficient type), not the live/root AIN type (owned by
      // MachineData.mode — the old ainAType/ainBType fields were removed
      // entirely, 2026-09) — [type]/[bType] passed in here already
      // carry the coefficient type (see advanced_config_screen.dart's
      // Parameter 07 call site), so they must be diffed against the same.
      // MachineData keeps the raw PAM token (e.g. "U"/"I"); [type]/[bType]
      // are always editable V/C — normalize the baseline before comparing.
      final aChanged =
          a != _md.expConfig.ainAa ||
          b != _md.expConfig.ainAb ||
          c != _md.expConfig.ainAc ||
          type != normalizeCoefType(_md.expConfig.ainACoefType);
      final bChanged =
          bA != _md.expConfig.ainBa ||
          bB != _md.expConfig.ainBb ||
          bC != _md.expConfig.ainBc ||
          bType != normalizeCoefType(_md.expConfig.ainBCoefType);
      if (aChanged && bChanged) {
        return execute(['AIN196:A:$a:$b:$c:$type:B:$bA:$bB:$bC:$bType']);
      } else if (aChanged) {
        return execute(['AIN:A $a $b $c $type']);
      } else if (bChanged) {
        return execute(['AIN:B $bA $bB $bC $bType']);
      }
      return execute(const []);
    }
    // Single-channel legacy call: no-op if this channel's values already
    // match the MachineData baseline, otherwise send it alone (unchanged
    // raw CMD_FORWARD_RAW passthrough).
    final baseA = channel == 'A' ? _md.expConfig.ainAa : _md.expConfig.ainBa;
    final baseB = channel == 'A' ? _md.expConfig.ainAb : _md.expConfig.ainBb;
    final baseC = channel == 'A' ? _md.expConfig.ainAc : _md.expConfig.ainBc;
    // Coefficient-type baseline (Parameter 07), not the live/root AIN type.
    // Normalize the raw PAM token (e.g. "U"/"I") to editable V/C before
    // comparing against [type], which is always V/C.
    final baseType = channel == 'A'
        ? normalizeCoefType(_md.expConfig.ainACoefType)
        : normalizeCoefType(_md.expConfig.ainBCoefType);
    if (a == baseA && b == baseB && c == baseC && type == baseType) {
      return execute(const []);
    }
    return execute(['AIN:$channel $a $b $c $type']);
  }
}
