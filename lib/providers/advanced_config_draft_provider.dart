import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/models/machine_data.dart';
import 'package:pvc_v2/utils/coef_normalizer.dart';
import 'package:pvc_v2/utils/pvc_debug_trace.dart';

// ---------------------------------------------------------------------------
// Advanced Config Draft — editable UI copy of parameter values.
//
// MachineData is the PAM/device truth (read-only from this provider's
// perspective).  The draft holds only what the user is currently editing.
// User edits modify the draft; MachineData is untouched until Save.
// ---------------------------------------------------------------------------
//
// Coefficient-type (V/C) normalization for this file's draft seeding and
// dirty-check crosses the same PAM-readback-vs-editable boundary as the
// write baseline in ble_command_controller.dart and the display in
// pam_data_screen.dart — see the shared normalizeCoefType() in
// utils/coef_normalizer.dart (single implementation as of 2026-09; this
// file used to carry its own private copy of the same logic).

class AdvancedConfigDraft {
  // ── Param 01 — Function ─────────────────────────────────────────────────
  final String func;

  // ── Param 02 — SENS ─────────────────────────────────────────────────────
  final String sens;

  // ── Param 03 — CC Mode ──────────────────────────────────────────────────
  final bool ccMode;

  // ── Param 04 — Enable-B ─────────────────────────────────────────────────
  final bool enableB;

  // ── Param 05 — LIMIT ────────────────────────────────────────────────────
  final int limGlobal;
  final int limA;
  final int limB;

  // ── Param 06 — POL ──────────────────────────────────────────────────────
  final String polGlobal;
  final String polA;
  final String polB;

  // ── Param 07 — AIN ──────────────────────────────────────────────────────
  // Parameter 07's editable coefficient type is ainACoefType/ainBCoefType,
  // seeded from md.expConfig.ainACoefType/ainBCoefType. The live/root AIN
  // input type (Basic Config semantics) is owned by MachineData.mode and
  // has no equivalent field in this draft.
  final String ainACoefType;
  final String ainBCoefType;
  final int ainAa;
  final int ainAb;
  final int ainAc;
  final int ainBa;
  final int ainBb;
  final int ainBc;

  // ── Param 08 — RAMP ─────────────────────────────────────────────────────
  final int rampAaUp;
  final int rampAaDown;
  final int rampAbUp;
  final int rampAbDown;

  // ── Param 09 — MIN ──────────────────────────────────────────────────────
  final int minA;
  final int minB;

  // ── Param 10 — MAX ──────────────────────────────────────────────────────
  final int maxA;
  final int maxB;

  // ── Param 11 — Trigger ──────────────────────────────────────────────────
  final int trigger;

  // ── Param 12 — Dither Amplitude ─────────────────────────────────────────
  final int ditherAmpGlobal;
  final int ditherAmpA;
  final int ditherAmpB;

  // ── Param 13 — Dither Frequency ─────────────────────────────────────────
  final int ditherFreqGlobal;
  final int ditherFreqA;
  final int ditherFreqB;

  // ── Param 14 — PWM Frequency ────────────────────────────────────────────
  final int pwmGlobal;
  final int pwmA;
  final int pwmB;

  // ── Param 15 — Current ──────────────────────────────────────────────────
  final double coilCurrent;
  final double coilACurrent;
  final double coilBCurrent;

  const AdvancedConfigDraft({
    this.func = '195',
    this.sens = 'AUTO',
    this.ccMode = false,
    this.enableB = false,
    this.limGlobal = 0,
    this.limA = 0,
    this.limB = 0,
    this.polGlobal = '+',
    this.polA = '+',
    this.polB = '+',
    this.ainACoefType = 'None',
    this.ainBCoefType = 'None',
    this.ainAa = 1000,
    this.ainAb = 1000,
    this.ainAc = 0,
    this.ainBa = 1000,
    this.ainBb = 1000,
    this.ainBc = 0,
    this.rampAaUp = 100,
    this.rampAaDown = 100,
    this.rampAbUp = 100,
    this.rampAbDown = 100,
    this.minA = 0,
    this.minB = 0,
    this.maxA = 10000,
    this.maxB = 10000,
    this.trigger = 200,
    this.ditherAmpGlobal = 500,
    this.ditherAmpA = 500,
    this.ditherAmpB = 500,
    this.ditherFreqGlobal = 121,
    this.ditherFreqA = 121,
    this.ditherFreqB = 121,
    this.pwmGlobal = 2604,
    this.pwmA = 2604,
    this.pwmB = 2604,
    this.coilCurrent = 0.0,
    this.coilACurrent = 0.0,
    this.coilBCurrent = 0.0,
  });

  /// Seed the draft from live PAM values.
  factory AdvancedConfigDraft.fromMachineData(MachineData md) {
    return AdvancedConfigDraft(
      func: md.func,
      sens: md.expConfig.sens,
      ccMode: md.expConfig.ccMode,
      enableB: md.enableB,
      limGlobal: md.expConfig.limGlobal,
      limA: md.expConfig.limA,
      limB: md.expConfig.limB,
      polGlobal: md.expConfig.polGlobal,
      polA: md.expConfig.polA,
      polB: md.expConfig.polB,
      // Seed Parameter 07's editable type from the coefficient-type fields
      // (never from the live/root AIN type, which this draft no longer
      // carries at all). Normalized: MachineData keeps the raw PAM token
      // (U/I/...); the draft — an editable UI copy — only ever holds V/C.
      ainACoefType: normalizeCoefType(md.expConfig.ainACoefType),
      ainBCoefType: normalizeCoefType(md.expConfig.ainBCoefType),
      ainAa: md.expConfig.ainAa,
      ainAb: md.expConfig.ainAb,
      ainAc: md.expConfig.ainAc,
      ainBa: md.expConfig.ainBa,
      ainBb: md.expConfig.ainBb,
      ainBc: md.expConfig.ainBc,
      rampAaUp: md.expConfig.rampAaUp,
      rampAaDown: md.expConfig.rampAaDown,
      rampAbUp: md.expConfig.rampAbUp,
      rampAbDown: md.expConfig.rampAbDown,
      minA: md.expConfig.minA,
      minB: md.expConfig.minB,
      maxA: md.expConfig.maxA,
      maxB: md.expConfig.maxB,
      trigger: md.expConfig.trigger,
      ditherAmpGlobal: md.expConfig.ditherAmpGlobal,
      ditherAmpA: md.expConfig.ditherAmpA,
      ditherAmpB: md.expConfig.ditherAmpB,
      ditherFreqGlobal: md.expConfig.ditherFreqGlobal,
      ditherFreqA: md.expConfig.ditherFreqA,
      ditherFreqB: md.expConfig.ditherFreqB,
      pwmGlobal: md.expConfig.pwmGlobal,
      pwmA: md.expConfig.pwmA,
      pwmB: md.expConfig.pwmB,
      coilCurrent: md.coilCurrent,
      coilACurrent: md.coilACurrent,
      coilBCurrent: md.coilBCurrent,
    );
  }

  AdvancedConfigDraft copyWith({
    String? func,
    String? sens,
    bool? ccMode,
    bool? enableB,
    int? limGlobal,
    int? limA,
    int? limB,
    String? polGlobal,
    String? polA,
    String? polB,
    String? ainACoefType,
    String? ainBCoefType,
    int? ainAa,
    int? ainAb,
    int? ainAc,
    int? ainBa,
    int? ainBb,
    int? ainBc,
    int? rampAaUp,
    int? rampAaDown,
    int? rampAbUp,
    int? rampAbDown,
    int? minA,
    int? minB,
    int? maxA,
    int? maxB,
    int? trigger,
    int? ditherAmpGlobal,
    int? ditherAmpA,
    int? ditherAmpB,
    int? ditherFreqGlobal,
    int? ditherFreqA,
    int? ditherFreqB,
    int? pwmGlobal,
    int? pwmA,
    int? pwmB,
    double? coilCurrent,
    double? coilACurrent,
    double? coilBCurrent,
  }) {
    return AdvancedConfigDraft(
      func: func ?? this.func,
      sens: sens ?? this.sens,
      ccMode: ccMode ?? this.ccMode,
      enableB: enableB ?? this.enableB,
      limGlobal: limGlobal ?? this.limGlobal,
      limA: limA ?? this.limA,
      limB: limB ?? this.limB,
      polGlobal: polGlobal ?? this.polGlobal,
      polA: polA ?? this.polA,
      polB: polB ?? this.polB,
      ainACoefType: ainACoefType ?? this.ainACoefType,
      ainBCoefType: ainBCoefType ?? this.ainBCoefType,
      ainAa: ainAa ?? this.ainAa,
      ainAb: ainAb ?? this.ainAb,
      ainAc: ainAc ?? this.ainAc,
      ainBa: ainBa ?? this.ainBa,
      ainBb: ainBb ?? this.ainBb,
      ainBc: ainBc ?? this.ainBc,
      rampAaUp: rampAaUp ?? this.rampAaUp,
      rampAaDown: rampAaDown ?? this.rampAaDown,
      rampAbUp: rampAbUp ?? this.rampAbUp,
      rampAbDown: rampAbDown ?? this.rampAbDown,
      minA: minA ?? this.minA,
      minB: minB ?? this.minB,
      maxA: maxA ?? this.maxA,
      maxB: maxB ?? this.maxB,
      trigger: trigger ?? this.trigger,
      ditherAmpGlobal: ditherAmpGlobal ?? this.ditherAmpGlobal,
      ditherAmpA: ditherAmpA ?? this.ditherAmpA,
      ditherAmpB: ditherAmpB ?? this.ditherAmpB,
      ditherFreqGlobal: ditherFreqGlobal ?? this.ditherFreqGlobal,
      ditherFreqA: ditherFreqA ?? this.ditherFreqA,
      ditherFreqB: ditherFreqB ?? this.ditherFreqB,
      pwmGlobal: pwmGlobal ?? this.pwmGlobal,
      pwmA: pwmA ?? this.pwmA,
      pwmB: pwmB ?? this.pwmB,
      coilCurrent: coilCurrent ?? this.coilCurrent,
      coilACurrent: coilACurrent ?? this.coilACurrent,
      coilBCurrent: coilBCurrent ?? this.coilBCurrent,
    );
  }
}

// ---------------------------------------------------------------------------
// Dirty check — compares draft values against PAM for the selected param.
// ---------------------------------------------------------------------------

bool hasChangesForSelectedParam(
  String selectedParam,
  String mode,
  AdvancedConfigDraft draft,
  MachineData md,
) {
  switch (selectedParam) {
    case '01':
      return draft.func != md.func;
    case '02':
      return draft.sens != md.expConfig.sens;
    case '03':
      return draft.ccMode != md.expConfig.ccMode;
    case '04':
      return draft.enableB != md.enableB;
    case '05':
      if (mode == '195') return draft.limGlobal != md.expConfig.limGlobal;
      return draft.limA != md.expConfig.limA || draft.limB != md.expConfig.limB;
    case '06':
      if (mode == '195') return draft.polGlobal != md.expConfig.polGlobal;
      return draft.polA != md.expConfig.polA || draft.polB != md.expConfig.polB;
    case '07':
      // AIN Type comparison uses the coefficient-type fields (ainACoefType/
      // ainBCoefType) — Parameter 07 is the editable coefficient type, not
      // the live/root AIN type, which Basic Config owns via MachineData.mode.
      // draft.ainACoefType/ainBCoefType are always normalized V/C (see
      // fromMachineData); md.expConfig.ainACoefType/ainBCoefType stay the
      // raw PAM token (e.g. "U"/"I") — normalize the PAM side here too so a
      // draft that matches PAM (just in the other alphabet) is never
      // reported dirty. Same normalizeCoefType() helper as the seed and the
      // write baseline in ble_command_controller.dart.
      if (draft.ainAa != md.expConfig.ainAa ||
          draft.ainAb != md.expConfig.ainAb ||
          draft.ainAc != md.expConfig.ainAc ||
          draft.ainACoefType != normalizeCoefType(md.expConfig.ainACoefType)) {
        return true;
      }
      if (mode == '196') {
        if (draft.ainBa != md.expConfig.ainBa ||
            draft.ainBb != md.expConfig.ainBb ||
            draft.ainBc != md.expConfig.ainBc ||
            draft.ainBCoefType !=
                normalizeCoefType(md.expConfig.ainBCoefType)) {
          return true;
        }
      }
      return false;
    case '08':
      return draft.rampAaUp != md.expConfig.rampAaUp ||
          draft.rampAaDown != md.expConfig.rampAaDown ||
          draft.rampAbUp != md.expConfig.rampAbUp ||
          draft.rampAbDown != md.expConfig.rampAbDown;
    case '09':
      return draft.minA != md.expConfig.minA || draft.minB != md.expConfig.minB;
    case '10':
      return draft.maxA != md.expConfig.maxA || draft.maxB != md.expConfig.maxB;
    case '11':
      return draft.trigger != md.expConfig.trigger;
    case '12':
      if (mode == '195') {
        return draft.ditherAmpGlobal != md.expConfig.ditherAmpGlobal;
      }
      return draft.ditherAmpA != md.expConfig.ditherAmpA ||
          draft.ditherAmpB != md.expConfig.ditherAmpB;
    case '13':
      if (mode == '195') {
        return draft.ditherFreqGlobal != md.expConfig.ditherFreqGlobal;
      }
      return draft.ditherFreqA != md.expConfig.ditherFreqA ||
          draft.ditherFreqB != md.expConfig.ditherFreqB;
    case '14':
      if (mode == '195') return draft.pwmGlobal != md.expConfig.pwmGlobal;
      return draft.pwmA != md.expConfig.pwmA || draft.pwmB != md.expConfig.pwmB;
    case '15':
      if (mode == '195') {
        return draft.coilCurrent.round() != md.coilCurrent.round();
      }
      return draft.coilACurrent.round() != md.coilACurrent.round() ||
          draft.coilBCurrent.round() != md.coilBCurrent.round();
    default:
      return false;
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AdvancedConfigDraftNotifier extends StateNotifier<AdvancedConfigDraft> {
  AdvancedConfigDraftNotifier() : super(const AdvancedConfigDraft());

  /// Seed draft from live PAM values (called on connect / F| snapshot).
  ///
  /// Debug-only tracing here is VERY important for finding the stale-draft
  /// race (a Draft edit landing just before/after a seed silently
  /// overwrites or is overwritten) — see pvc_debug_trace.dart.
  void seedFromMachineData(MachineData md) {
    if (kPvcDebugProtocol) {
      final old = state;
      pvcTrace('DRAFT_SEED', 'pamMode=${md.pamMode} func=${md.func}');
      pvcTrace(
        'DRAFT_SEED',
        'AIN_A before=${old.ainAa}/${old.ainAb}/${old.ainAc}/${old.ainACoefType} '
            'after=${md.expConfig.ainAa}/${md.expConfig.ainAb}/${md.expConfig.ainAc}/${md.expConfig.ainACoefType}',
      );
      pvcTrace(
        'DRAFT_SEED',
        'AIN_B before=${old.ainBa}/${old.ainBb}/${old.ainBc}/${old.ainBCoefType} '
            'after=${md.expConfig.ainBa}/${md.expConfig.ainBb}/${md.expConfig.ainBc}/${md.expConfig.ainBCoefType}',
      );
      pvcTrace(
        'DRAFT_SEED',
        'CURRENT before=${old.coilCurrent}/${old.coilACurrent}/${old.coilBCurrent} '
            'after=${md.coilCurrent}/${md.coilACurrent}/${md.coilBCurrent}',
      );
    }
    state = AdvancedConfigDraft.fromMachineData(md);
  }

  /// After successful Save: re-sync draft from PAM so Save disables.
  void syncFromMachineData(MachineData md) {
    state = AdvancedConfigDraft.fromMachineData(md);
  }

  // ── Individual setters (only touch the draft, never MachineData) ────────

  void setFunc(String v) => state = state.copyWith(func: v);
  void setSens(String v) => state = state.copyWith(sens: v);
  void setCcMode(bool v) => state = state.copyWith(ccMode: v);
  void setEnableB(bool v) => state = state.copyWith(enableB: v);

  void setLimGlobal(int v) => state = state.copyWith(limGlobal: v);
  void setLimA(int v) => state = state.copyWith(limA: v);
  void setLimB(int v) => state = state.copyWith(limB: v);

  void setPolGlobal(String v) => state = state.copyWith(polGlobal: v);
  void setPolA(String v) => state = state.copyWith(polA: v);
  void setPolB(String v) => state = state.copyWith(polB: v);

  // Debug-only: logs the AIN_A/AIN_B a/b/c/type group before -> after,
  // matching the trace spec's example format, only when the call actually
  // changes a value. No-op when kPvcDebugProtocol is false.
  void _traceAinA(AdvancedConfigDraft old) {
    if (!kPvcDebugProtocol) return;
    final n = state;
    if (old.ainAa == n.ainAa &&
        old.ainAb == n.ainAb &&
        old.ainAc == n.ainAc &&
        old.ainACoefType == n.ainACoefType) {
      return;
    }
    pvcTrace(
      'DRAFT',
      'AIN_A = ${old.ainAa}/${old.ainAb}/${old.ainAc}/${old.ainACoefType} -> '
          '${n.ainAa}/${n.ainAb}/${n.ainAc}/${n.ainACoefType}',
    );
  }

  void _traceAinB(AdvancedConfigDraft old) {
    if (!kPvcDebugProtocol) return;
    final n = state;
    if (old.ainBa == n.ainBa &&
        old.ainBb == n.ainBb &&
        old.ainBc == n.ainBc &&
        old.ainBCoefType == n.ainBCoefType) {
      return;
    }
    pvcTrace(
      'DRAFT',
      'AIN_B = ${old.ainBa}/${old.ainBb}/${old.ainBc}/${old.ainBCoefType} -> '
          '${n.ainBa}/${n.ainBb}/${n.ainBc}/${n.ainBCoefType}',
    );
  }

  // Parameter 07's editable coefficient-type setters.
  void setAinACoefType(String v) {
    final old = state;
    state = state.copyWith(ainACoefType: v);
    _traceAinA(old);
  }

  void setAinBCoefType(String v) {
    final old = state;
    state = state.copyWith(ainBCoefType: v);
    _traceAinB(old);
  }

  void setAinAa(int v) {
    final old = state;
    state = state.copyWith(ainAa: v);
    _traceAinA(old);
  }

  void setAinAb(int v) {
    final old = state;
    state = state.copyWith(ainAb: v);
    _traceAinA(old);
  }

  void setAinAc(int v) {
    final old = state;
    state = state.copyWith(ainAc: v);
    _traceAinA(old);
  }

  void setAinBa(int v) {
    final old = state;
    state = state.copyWith(ainBa: v);
    _traceAinB(old);
  }

  void setAinBb(int v) {
    final old = state;
    state = state.copyWith(ainBb: v);
    _traceAinB(old);
  }

  void setAinBc(int v) {
    final old = state;
    state = state.copyWith(ainBc: v);
    _traceAinB(old);
  }

  void setRampAaUp(int v) => state = state.copyWith(rampAaUp: v);
  void setRampAaDown(int v) => state = state.copyWith(rampAaDown: v);
  void setRampAbUp(int v) => state = state.copyWith(rampAbUp: v);
  void setRampAbDown(int v) => state = state.copyWith(rampAbDown: v);

  void setMinA(int v) => state = state.copyWith(minA: v);
  void setMinB(int v) => state = state.copyWith(minB: v);
  void setMaxA(int v) => state = state.copyWith(maxA: v);
  void setMaxB(int v) => state = state.copyWith(maxB: v);

  void setTrigger(int v) => state = state.copyWith(trigger: v);

  void setDitherAmpGlobal(int v) => state = state.copyWith(ditherAmpGlobal: v);
  void setDitherAmpA(int v) => state = state.copyWith(ditherAmpA: v);
  void setDitherAmpB(int v) => state = state.copyWith(ditherAmpB: v);
  void setDitherFreqGlobal(int v) =>
      state = state.copyWith(ditherFreqGlobal: v);
  void setDitherFreqA(int v) => state = state.copyWith(ditherFreqA: v);
  void setDitherFreqB(int v) => state = state.copyWith(ditherFreqB: v);

  void setPwmGlobal(int v) => state = state.copyWith(pwmGlobal: v);
  void setPwmA(int v) => state = state.copyWith(pwmA: v);
  void setPwmB(int v) => state = state.copyWith(pwmB: v);

  void setCurrent(double v) {
    final old = state.coilCurrent;
    state = state.copyWith(coilCurrent: v);
    if (kPvcDebugProtocol && old != v) {
      pvcTrace('DRAFT', 'CURRENT_S = $old -> $v');
    }
  }

  void setCurrentA(double v) {
    final old = state.coilACurrent;
    state = state.copyWith(coilACurrent: v);
    if (kPvcDebugProtocol && old != v) {
      pvcTrace('DRAFT', 'CURRENT_A = $old -> $v');
    }
  }

  void setCurrentB(double v) {
    final old = state.coilBCurrent;
    state = state.copyWith(coilBCurrent: v);
    if (kPvcDebugProtocol && old != v) {
      pvcTrace('DRAFT', 'CURRENT_B = $old -> $v');
    }
  }
}

final advancedConfigDraftProvider =
    StateNotifierProvider<AdvancedConfigDraftNotifier, AdvancedConfigDraft>(
      (ref) => AdvancedConfigDraftNotifier(),
    );

/// Which parameter card ('01'..'15') Advanced Config currently shows.
///
/// Deliberately NOT a field on [AdvancedConfigDraft]: that class holds PAM
/// value data diffed against MachineData for dirty-tracking/Save
/// (hasChangesForSelectedParam, writeOp dispatch), and this is pure
/// UI/navigation state with no bearing on either — keeping it separate means
/// this selection can never affect dirty tracking, Save, or PAM
/// communication. It lives in a provider (not widget State) specifically so
/// it survives HomeScreen swapping AdvancedConfigScreen out of the bottom
/// nav's `_children[_currentIndex]` (which disposes/recreates the screen's
/// State on every Home <-> Configure switch) — a plain `State<>` field
/// resets on that recreation; a provider held in the app's ProviderScope
/// does not. Defaults to '01' on first-ever read. Session-only (in-memory,
/// like every other provider here) — no persistent storage added.
final selectedAdvancedConfigParamProvider = StateProvider<String>(
  (ref) => '01',
);
