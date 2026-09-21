import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/models/machine_data.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/providers/processing_overlay_provider.dart';
import 'package:pvc_v2/utils/coef_normalizer.dart';

// Coefficient-type (V/C) normalization below (write-baseline comparisons)
// crosses the same PAM-readback-vs-editable boundary as draft seeding/dirty
// check in advanced_config_draft_provider.dart and the display in
// pam_data_screen.dart — see the shared normalizeCoefType() in
// utils/coef_normalizer.dart (single implementation as of 2026-09; this
// file used to carry its own private copy of the same logic).

/// Shared BLE command controller used by both basic (STD) and advanced screens.
///
/// Handles:
///  * sequential command execution with transition polling
///  * overlay / busy-guard management
///  * SAVE (EEPROM persist) helper
///  * success / failure messages
class BleCommandController {
  BleCommandController(this._ref);

  final Ref _ref;

  // ── Timing constants ─────────────────────────────────────────────────────
  static const Duration ackTimeout = Duration(seconds: 3);
  static const Duration doneTimeoutFunctionChange = Duration(seconds: 10);
  static const Duration doneTimeoutParameterChange = Duration(seconds: 4);

  // ── Convenience getters ──────────────────────────────────────────────────
  BleNotifier get _ble => _ref.read(bleProvider.notifier);
  StateController<bool> get _overlay =>
      _ref.read(processingOverlayProvider.notifier);
  GlobalMessageNotifier get _msg => _ref.read(globalMessageProvider.notifier);
  MachineData get _md => _ref.read(machineDataProvider);

  /// Whether the device is currently busy.
  bool get isBusy => _md.transition;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Execute [commands] sequentially, waiting for the device transition after
  /// each write.  Returns `true` when every command succeeds.
  ///
  /// * [isModeChange] – when `true`, the longer 10 s timeout is used.
  /// * When [showOverlay] is `true` (default), the processing overlay is
  ///   displayed for the duration of execution.
  /// * [onProgress] – optional callback with the 1-based index of the command
  ///   currently being sent (useful for a progress indicator).
  Future<bool> execute(
    List<String> commands, {
    bool isModeChange = false,
    bool showOverlay = true,
    void Function(int index, int total)? onProgress,
  }) async {
    if (commands.isEmpty) return true;

    if (showOverlay) _overlay.state = true;

    final timeout = isModeChange
        ? doneTimeoutFunctionChange
        : doneTimeoutParameterChange;
    var allSuccess = true;

    for (var i = 0; i < commands.length; i++) {
      onProgress?.call(i + 1, commands.length);

      final writeOk = await _ble.writeToCharacteristic(
        commands[i],
        busyTimeout: timeout,
      );
      if (!writeOk) {
        allSuccess = false;
        break;
      }
      if (!await _waitForTransition(timeout)) {
        allSuccess = false;
        _ble.setBusy(false);
        break;
      }
    }

    if (showOverlay) _overlay.state = false;
    return allSuccess;
  }

  /// Send the `SAVE` command to persist current parameters to PAM EEPROM.
  ///
  /// SAVE is deliberately NOT routed through execute()/_waitForTransition().
  /// The firmware forwards SAVE through the same generic command pipeline
  /// as every other command, so it still emits its own
  /// TRANSITION:True → TRANSITION:False pair while processing it — that is
  /// firmware behavior we don't (and can't) change. But that cycle belongs
  /// to EEPROM housekeeping, not a parameter write, so the app has no
  /// reason to block a Save operation on it. See _sendSaveOnly() below.
  Future<bool> saveToEeprom({bool showOverlay = true}) async {
    return _sendSaveOnly(showOverlay: showOverlay);
  }

  /// Dedicated internal execution path for EEPROM SAVE.
  ///
  /// Mirrors execute()'s write step (busy-guard + write ack, same
  /// parameter-change timeout) but intentionally skips
  /// _waitForTransition(). The device's `isBusy` flag still clears itself
  /// normally once the firmware's own TRANSITION:False telemetry for SAVE
  /// arrives — that happens in BleNotifier's telemetry listener,
  /// independently of this call — so busy-guard protection against
  /// double-taps is unaffected; this method just doesn't `await` it.
  Future<bool> _sendSaveOnly({bool showOverlay = true}) async {
    if (showOverlay) _overlay.state = true;

    final writeOk = await _ble.writeToCharacteristic(
      'SAVE',
      busyTimeout: doneTimeoutParameterChange,
    );

    if (showOverlay) _overlay.state = false;
    return writeOk;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // High-level per-parameter write helpers — Advanced Config.
  //
  // Each method sends ONLY the command(s) for that one parameter group,
  // via the shared execute() mechanism above (same ACK/transition/busy/
  // timeout/overlay handling as everything else). None of them call
  // saveToEeprom() — persistence stays a separate, caller-controlled step.
  //
  // Wire formats below are NOT invented here: single-value/per-channel
  // params (SENS/CCMODE/ENABLE_B/TRIGGER/MIN/MAX/LIM/POL/DAMPL/DFREQ/PWM/
  // ramp) mirror the exact colon syntax commands.cpp's parseBleCommand()
  // already parses into tracked CMD_SET_PARAM writes (with PAM readback +
  // gState caching). FUNCTION reuses the existing CMD_CHANGE_MODE legacy
  // bare-mode path. CURRENT reuses Basic Config's existing CUR/CURA/CURB
  // format. AIN/PPWM/IPWM/ACC have no tracked firmware support (they fall
  // through to CMD_FORWARD_RAW) so they keep the exact raw string shape
  // already used for them previously.
  // ═══════════════════════════════════════════════════════════════════════

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

  /// Param 05 — LIMIT. Mode 195 uses the single global value; mode 196
  /// uses the independent A/B values. Only the channel(s) whose draft
  /// value actually differs from the current MachineData baseline are
  /// sent: neither changed → no command, one changed → that channel's
  /// existing single command, both changed → one grouped command.
  Future<bool> writeLimit({required String mode, int? global, int? a, int? b}) {
    if (mode == '196') {
      final aChanged = a != null && a != _md.expConfig.limA;
      final bChanged = b != null && b != _md.expConfig.limB;
      if (aChanged && bChanged) {
        return execute(['LIM:A:$a:B:$b']);
      } else if (aChanged) {
        return execute(['LIM_A:$a']);
      } else if (bChanged) {
        return execute(['LIM_B:$b']);
      }
      return execute(const []);
    }
    return execute(['LIM:$global']);
  }

  /// Param 06 — POL (polarity). Same 195/196 shape and same
  /// draft-vs-MachineData diffing as LIMIT.
  Future<bool> writePolarity({
    required String mode,
    String? global,
    String? a,
    String? b,
  }) {
    if (mode == '196') {
      final aChanged = a != null && a != _md.expConfig.polA;
      final bChanged = b != null && b != _md.expConfig.polB;
      if (aChanged && bChanged) {
        return execute(['POL:A:$a:B:$b']);
      } else if (aChanged) {
        return execute(['POL_A:$a']);
      } else if (bChanged) {
        return execute(['POL_B:$b']);
      }
      return execute(const []);
    }
    return execute(['POL:$global']);
  }

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

  /// Param 09 — MIN. Always per-channel, in both modes. Neither changed →
  /// no command, one changed → that channel's existing single command,
  /// both changed → one grouped CMD_SET_PARAM_GROUP command.
  Future<bool> writeMin(int a, int b) {
    final aChanged = a != _md.expConfig.minA;
    final bChanged = b != _md.expConfig.minB;
    if (aChanged && bChanged) {
      return execute(['MIN:A:$a:B:$b']);
    } else if (aChanged) {
      return execute(['MIN_A:$a']);
    } else if (bChanged) {
      return execute(['MIN_B:$b']);
    }
    return execute(const []);
  }

  /// Param 10 — MAX. Same diffing as MIN.
  Future<bool> writeMax(int a, int b) {
    final aChanged = a != _md.expConfig.maxA;
    final bChanged = b != _md.expConfig.maxB;
    if (aChanged && bChanged) {
      return execute(['MAX:A:$a:B:$b']);
    } else if (aChanged) {
      return execute(['MAX_A:$a']);
    } else if (bChanged) {
      return execute(['MAX_B:$b']);
    }
    return execute(const []);
  }

  /// Param 11 — Trigger.
  Future<bool> writeTrigger(int value) {
    return execute(['TRIGGER:$value']);
  }

  /// Param 12 — Dither Amplitude. Diffed against MachineData like LIMIT.
  Future<bool> writeDitherAmplitude({
    required String mode,
    int? global,
    int? a,
    int? b,
  }) {
    if (mode == '196') {
      final aChanged = a != null && a != _md.expConfig.ditherAmpA;
      final bChanged = b != null && b != _md.expConfig.ditherAmpB;
      if (aChanged && bChanged) {
        return execute(['DAMPL:A:$a:B:$b']);
      } else if (aChanged) {
        return execute(['DAMPL_A:$a']);
      } else if (bChanged) {
        return execute(['DAMPL_B:$b']);
      }
      return execute(const []);
    }
    return execute(['DAMPL:$global']);
  }

  /// Param 13 — Dither Frequency. Diffed against MachineData like LIMIT.
  Future<bool> writeDitherFrequency({
    required String mode,
    int? global,
    int? a,
    int? b,
  }) {
    if (mode == '196') {
      final aChanged = a != null && a != _md.expConfig.ditherFreqA;
      final bChanged = b != null && b != _md.expConfig.ditherFreqB;
      if (aChanged && bChanged) {
        return execute(['DFREQ:A:$a:B:$b']);
      } else if (aChanged) {
        return execute(['DFREQ_A:$a']);
      } else if (bChanged) {
        return execute(['DFREQ_B:$b']);
      }
      return execute(const []);
    }
    return execute(['DFREQ:$global']);
  }

  /// Param 14 — PWM Frequency. Diffed against MachineData like LIMIT.
  Future<bool> writePwm({required String mode, int? global, int? a, int? b}) {
    if (mode == '196') {
      final aChanged = a != null && a != _md.expConfig.pwmA;
      final bChanged = b != null && b != _md.expConfig.pwmB;
      if (aChanged && bChanged) {
        return execute(['PWM:A:$a:B:$b']);
      } else if (aChanged) {
        return execute(['PWM_A:$a']);
      } else if (bChanged) {
        return execute(['PWM_B:$b']);
      }
      return execute(const []);
    }
    return execute(['PWM:$global']);
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

  /// App-only preference cache — tells the ESP which config screen (Basic
  /// or Advanced) just saved successfully, so MachineData.configView (and
  /// the device's own RAM-only cache) reflects it. NOT a PAM write — no PAM
  /// access, no SAVE, no transition — see CMD_SET_CONFIG_VIEW / configView
  /// in the ESP firmware. NOTE: configView is no longer the authority for
  /// which config screen is shown (see [MachineData.pamMode] /
  /// [setPamMode] for that) — this is kept only for its remaining purpose,
  /// the F|-snapshot active/inactive section merge routing in
  /// MachineData's packet parser (so saving one screen's parameters can
  /// never clobber the other screen's locally-cached values). [view] must
  /// be exactly 'STD' (Basic) or 'EXP' (Advanced).
  Future<bool> setConfigView(String view) {
    // Bypasses the busy-guard entirely: CONFIG_VIEW is app-side preference
    // state, not a PAM transition, so it must never be dropped by (or
    // contribute to) the busy lifecycle. See writeRawToCharacteristic().
    return _ble.writeRawToCharacteristic('CONFIG_VIEW:$view');
  }

  /// Sets the ACTUAL PAM hardware MODE (STD/EXP) — the single source of
  /// truth for which config screen (Basic/Advanced) PVC shows (see
  /// [MachineData.pamMode] / ConfigScreen). Only ever called from an
  /// explicit user action (the drawer's Basic/Advanced selector) — never
  /// automatically on connect/reconnect. Unlike [setConfigView], this IS a
  /// real PAM write: the ESP performs MODE STD/EXP -> SAVE as one atomic
  /// transaction (see handleSetPamMode() in commands.cpp), reusing the same
  /// busy-guard + TRANSITION:True/...  /TRANSITION:False sequencing every
  /// other PAM-touching command already goes through via [execute] — no
  /// separate SAVE call is needed here, and none is sent. [mode] must be
  /// exactly 'STD' (Basic) or 'EXP' (Advanced).
  Future<bool> setPamMode(String mode) {
    return execute(['PAM_MODE:$mode']);
  }

  /// Build + execute a full save sequence:
  /// 1. [commands] – the parameter writes
  /// 2. `SAVE` – persist to EEPROM
  ///
  /// Shows the overlay, sends all commands, then persists.
  /// Returns `true` when everything succeeds.
  Future<bool> executeAndSave(
    List<String> commands, {
    bool isModeChange = false,
    void Function(int index, int total)? onProgress,
  }) async {
    if (_md.transition) {
      _msg.showError('Device is busy, please wait');
      return false;
    }

    if (commands.isEmpty) {
      _msg.showSuccess('Nothing to save');
      return true;
    }

    _overlay.state = true;

    final timeout = isModeChange
        ? doneTimeoutFunctionChange
        : doneTimeoutParameterChange;
    var allSuccess = true;

    // ── Send parameter commands ──────────────────────────────────────────
    for (var i = 0; i < commands.length; i++) {
      onProgress?.call(i + 1, commands.length + 1); // +1 for SAVE

      final writeOk = await _ble.writeToCharacteristic(
        commands[i],
        busyTimeout: timeout,
      );
      if (!writeOk) {
        allSuccess = false;
        break;
      }
      if (!await _waitForTransition(timeout)) {
        allSuccess = false;
        _ble.setBusy(false);
        break;
      }
    }

    // ── Persist to EEPROM ────────────────────────────────────────────────
    // Uses the dedicated SAVE path (no transition-wait) — see saveToEeprom().
    if (allSuccess) {
      onProgress?.call(commands.length + 1, commands.length + 1);
      allSuccess = await _sendSaveOnly(showOverlay: false);
    }

    _overlay.state = false;
    return allSuccess;
  }

  // ── Transition polling ────────────────────────────────────────────────────

  /// Wait for the device to acknowledge (transition → true) within [ackTimeout],
  /// then wait for it to finish (transition → false) within [doneTimeout].
  Future<bool> _waitForTransition(Duration doneTimeout) async {
    final ackSw = Stopwatch()..start();
    var seenTrue = false;

    while (ackSw.elapsed < ackTimeout) {
      if (_md.transition) {
        seenTrue = true;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 10));
    }

    if (!seenTrue && !_md.transition) return true;
    return _waitForDone(doneTimeout);
  }

  Future<bool> _waitForDone(Duration doneTimeout) async {
    final sw = Stopwatch()..start();
    while (sw.elapsed < doneTimeout) {
      if (!_md.transition) return true;
      await Future.delayed(const Duration(milliseconds: 10));
    }
    return false;
  }
}

/// Provider that exposes a [BleCommandController] scoped to the current
/// Riverpod container.  Both screens can `ref.watch(bleCommandProvider)`.
final bleCommandProvider = Provider<BleCommandController>((ref) {
  return BleCommandController(ref);
});
