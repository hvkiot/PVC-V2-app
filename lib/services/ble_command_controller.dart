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

// ═══════════════════════════════════════════════════════════════════════
// STRUCTURAL SPLIT (Phase 3, 2026-09): this file is the library root for
// the BleCommandController library — imports, the class's core state/queue
// members, and `part` directives. The per-parameter write methods live in
// the `ble_command_controller/` part files below, contributed to the class
// via mixins. This is a pure code-motion / file re-organization: no
// command string, parameter ID, timing value, retry/timeout, busy-guard,
// protocol, or provider behavior changed.
//
// Why mixins (not just part/part-of on their own): unlike Phase 2's
// parameter_widgets.dart, which held many independent top-level widget
// classes, this file is ONE class (BleCommandController) with ~20 instance
// methods. Dart has no "partial class" feature — a class's members must
// all be declared in one contiguous class body, even across part files in
// the same library. The only mechanical way to move a subset of one
// class's methods into their own file is a mixin, applied to the class via
// `with`.
//
// Each mixin declares two minimal ABSTRACT members it needs —
// `Future<bool> execute(...)` and `MachineData get _md` — restating the
// exact signatures BleCommandController's own class body already
// implements concretely, and the mixin's own methods call them normally.
// (An earlier draft of this split tried `mixin X on BleCommandController`
// so each mixin could reach BleCommandController's members implicitly —
// that fails to compile: `class BleCommandController with X` while `X`
// itself extends-constrains on `BleCommandController` is a circular
// supertype declaration, rejected by the analyzer as
// recursive_interface_inheritance. The abstract-redeclaration form below
// is the correct, non-circular version of the same idea.) This is still
// zero new PUBLIC interface — the abstract redeclarations are private,
// exist only to satisfy the mixin-composition mechanism, and no member was
// made public or renamed to allow this split.
//
// Each part file's first line is `part of '../ble_command_controller.dart';`.
// Only this root file holds `import`s; per Dart part-file rules the
// per-parameter-write files below use `execute()`, `_md`, and (in
// ain_coefficient_writes.dart) `normalizeCoefType()` directly, without
// their own imports.
//
// Public symbols (unchanged since before the split): BleCommandController
// (class), bleCommandProvider, and every existing public method —
// execute, saveToEeprom, executeAndSave, setConfigView, setPamMode,
// isBusy, ackTimeout/doneTimeoutFunctionChange/doneTimeoutParameterChange,
// and all 18 parameter-write methods (writeFunction .. writeAcceleration).
// advanced_config_screen.dart, basic_config_screen.dart, and
// custom_drawer.dart — the only external consumers — needed zero changes.
//
// See AGENTS.md "Phase 3 — BleCommandController structural split
// (2026-09)" for the full audit and file-grouping rationale.
// ═══════════════════════════════════════════════════════════════════════

part 'ble_command_controller/simple_parameter_writes.dart';
part 'ble_command_controller/diffed_parameter_writes.dart';
part 'ble_command_controller/ain_coefficient_writes.dart';
part 'ble_command_controller/current_ramp_writes.dart';

/// Shared BLE command controller used by both basic (STD) and advanced screens.
///
/// Handles:
///  * sequential command execution with transition polling
///  * overlay / busy-guard management
///  * SAVE (EEPROM persist) helper
///  * success / failure messages
///
/// High-level per-parameter write helpers — Advanced Config.
///
/// Each method sends ONLY the command(s) for that one parameter group,
/// via the shared execute() mechanism above (same ACK/transition/busy/
/// timeout/overlay handling as everything else). None of them call
/// saveToEeprom() — persistence stays a separate, caller-controlled step.
///
/// Wire formats below are NOT invented here: single-value/per-channel
/// params (SENS/CCMODE/ENABLE_B/TRIGGER/MIN/MAX/LIM/POL/DAMPL/DFREQ/PWM/
/// ramp) mirror the exact colon syntax commands.cpp's parseBleCommand()
/// already parses into tracked CMD_SET_PARAM writes (with PAM readback +
/// gState caching). FUNCTION reuses the existing CMD_CHANGE_MODE legacy
/// bare-mode path. CURRENT reuses Basic Config's existing CUR/CURA/CURB
/// format. AIN/PPWM/IPWM/ACC have no tracked firmware support (they fall
/// through to CMD_FORWARD_RAW) so they keep the exact raw string shape
/// already used for them previously.
///
/// (Phase 3, 2026-09: these write helpers now live in the
/// `ble_command_controller/` part files, contributed via mixins — see the
/// file-banner comment above. This doc comment is unchanged from before
/// the split.)
class BleCommandController
    with
        _SimpleParameterWrites,
        _DiffedParameterWrites,
        _AinCoefficientWrites,
        _CurrentRampWrites {
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
  @override
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
  @override
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
