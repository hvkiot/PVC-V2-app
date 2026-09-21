import 'package:json_annotation/json_annotation.dart';
import 'package:logger/logger.dart';
import 'package:pvc_v2/utils/pvc_debug_trace.dart';

// This is required for the generator to work
part 'machine_data.g.dart';

/// Advanced config boolean wire keys (BLE name → ExpConfig boolean field).
const _cfgBoolKeys = {'CCMODE', 'ACC'};

/// Advanced config integer wire keys.
const _cfgIntKeys = {
  'LIM_GLOBAL',
  'LIM_A',
  'LIM_B',
  'MAX',
  'MAX_A',
  'MAX_B',
  'MIN',
  'MIN_A',
  'MIN_B',
  'RAMP_A_UP',
  'RAMP_A_DOWN',
  'RAMP_B_UP',
  'RAMP_B_DOWN',
  'TRIGGER',
  'DAMPL_GLOBAL',
  'DAMPL_A',
  'DAMPL_B',
  'DFREQ_GLOBAL',
  'DFREQ_A',
  'DFREQ_B',
  'PWM_GLOBAL',
  'PWM_A',
  'PWM_B',
  'PPWM',
  'PPWM_A',
  'PPWM_B',
  'IPWM',
  'IPWM_A',
  'IPWM_B',
  'CURRENT_GLOBAL',
  'AIN_AA',
  'AIN_AB',
  'AIN_AC',
  'AIN_BA',
  'AIN_BB',
  'AIN_BC',
};

/// Advanced config string wire keys.
///
/// NOTE: AIN_A_TYPE/AIN_B_TYPE are intentionally NOT wired here. The ESP no
/// longer sends them in D| (removed from buildDeltaPacket()'s DF_AIN_A/
/// DF_AIN_B blocks) or F| (removed from buildFullPacket()) — Basic Config
/// reads the live AIN type from the top-level MODE field instead (see
/// basic_config_screen.dart, which only ever reads machineData.mode).
/// ExpConfig.ainAType/ainBType have been removed entirely (2026-09, along
/// with their AdvancedConfigDraft/machine_data.g.dart counterparts) —
/// Parameter 07 uses ainACoefType/ainBCoefType instead (see below).
const _cfgStringKeys = {
  'SENS',
  'POL_GLOBAL',
  'POL_A',
  'POL_B',
  // Parameter-07 (Advanced AIN) editable coefficient type — distinct from
  // the live/root AIN input type (MODE) Basic Config owns. See
  // ExpConfig.ainACoefType/ainBCoefType below.
  'AIN_A_COEF_TYPE',
  'AIN_B_COEF_TYPE',
};

/// Wire keys that carry the Basic (STD) config section. `FUNC`, `MODE` and
/// `CURRENT_*` remain shared root fields; they are also snapshotted into
/// [StdConfig] so each section carries a self-contained copy for the
/// baseline/diff logic.
const _stdGroupKeys = {
  'FUNC',
  'MODE',
  'CURRENT_S',
  'CURRENT_STATUS',
  'CURRENT_A',
  'CURRENT_A_STATUS',
  'CURRENT_B',
  'CURRENT_B_STATUS',
};

/// Wire keys that carry the Advanced (EXP) config section.
const _expGroupKeys = <String>{
  ..._cfgBoolKeys,
  ..._cfgIntKeys,
  ..._cfgStringKeys,
};

/// Default view for a device that has never reported/been saved as EXP.
const _defaultConfigView = 'STD';

/// Returns the raw string value for [wireKey] if present, else null.
String? _strOf(Map<String, String> raw, String wireKey) => raw[wireKey];

/// Returns the first present alias parsed as a double (legacy behavior:
/// `double.tryParse ?? 0.0`), else [fallback].
double _dblOf(Map<String, String> raw, List<String> wireKeys, double fallback) {
  for (final k in wireKeys) {
    final v = raw[k];
    if (v != null) return double.tryParse(v) ?? 0.0;
  }
  return fallback;
}

/// Returns the first present alias parsed as a bool (`'true'`, case
/// insensitive), else [fallback].
bool _boolOf(Map<String, String> raw, List<String> wireKeys, bool fallback) {
  for (final k in wireKeys) {
    final v = raw[k];
    if (v != null) return v.toLowerCase() == 'true';
  }
  return fallback;
}

/// Returns the first present alias parsed as an on/off bool (`'ON'`, case
/// insensitive), matching the ESP32's `CCMODE:ON`/`ACC:OFF` wire encoding.
bool _onOf(Map<String, String> raw, List<String> wireKeys, bool fallback) {
  for (final k in wireKeys) {
    final v = raw[k];
    if (v != null) return v.toUpperCase() == 'ON';
  }
  return fallback;
}

/// Returns the first present alias parsed as an int (legacy behavior:
/// `int.tryParse ?? 0`), else [fallback].
int _intOf(Map<String, String> raw, List<String> wireKeys, int fallback) {
  for (final k in wireKeys) {
    final v = raw[k];
    if (v != null) return int.tryParse(v) ?? 0;
  }
  return fallback;
}

/// True if [raw] contains any key from [keys].
bool _hasAny(Map<String, String> raw, Set<String> keys) =>
    raw.keys.any(keys.contains);

/// Basic (STD) config section — a self-contained snapshot of the shared
/// `FUNC`/`MODE`/`CURRENT_*` fields, used for baseline/diff on that view.
@JsonSerializable()
class StdConfig {
  @JsonKey(name: 'FUNC')
  final String func;

  @JsonKey(name: 'MODE')
  final String mode;

  @JsonKey(name: 'CURRENT_S')
  final double coilCurrent;

  @JsonKey(name: 'CURRENT_A')
  final double coilACurrent;

  @JsonKey(name: 'CURRENT_B')
  final double coilBCurrent;

  const StdConfig({
    this.func = '195',
    this.mode = '0',
    this.coilCurrent = 0.0,
    this.coilACurrent = 0.0,
    this.coilBCurrent = 0.0,
  });

  factory StdConfig.fromJson(Map<String, dynamic> json) =>
      _$StdConfigFromJson(json);

  Map<String, dynamic> toJson() => _$StdConfigToJson(this);

  /// Overlays every STD wire key present in [raw] onto [seed], leaving the
  /// rest of [seed] untouched. Both the F| active-section path (seed = const
  /// default → fresh copy) and the D|/L| delta path (seed = carried value →
  /// merge) go through here.
  static StdConfig fromWire(Map<String, String> raw, StdConfig seed) {
    return StdConfig(
      func: _strOf(raw, 'FUNC') ?? seed.func,
      mode: _strOf(raw, 'MODE') ?? seed.mode,
      coilCurrent: _dblOf(raw, const [
        'CURRENT_S',
        'CURRENT_STATUS',
      ], seed.coilCurrent),
      coilACurrent: _dblOf(raw, const [
        'CURRENT_A',
        'CURRENT_A_STATUS',
      ], seed.coilACurrent),
      coilBCurrent: _dblOf(raw, const [
        'CURRENT_B',
        'CURRENT_B_STATUS',
      ], seed.coilBCurrent),
    );
  }
}

/// Advanced (EXP) config section — every field the Advanced Config screen
/// edits and writes back via the ESP32's CMD `CFG_*` family.
@JsonSerializable()
class ExpConfig {
  @JsonKey(name: 'SENS')
  final String sens;

  @JsonKey(name: 'CCMODE')
  final bool ccMode;

  @JsonKey(name: 'LIM_GLOBAL')
  final int limGlobal;

  @JsonKey(name: 'LIM_A')
  final int limA;

  @JsonKey(name: 'LIM_B')
  final int limB;

  @JsonKey(name: 'POL_GLOBAL')
  final String polGlobal;

  @JsonKey(name: 'POL_A')
  final String polA;

  @JsonKey(name: 'POL_B')
  final String polB;

  /// Parameter-07 (Advanced Config) editable AIN coefficient type — "V",
  /// "C", or "I" (PAM readback uses "I" for current; the app's own AIN edit
  /// dialog writes "C" — both mean the same coefficient type, see the
  /// display mapping in advanced_config_screen.dart). This is NOT the same
  /// concept as the live/root AIN input type — that lives solely in
  /// [MachineData.mode] (read from the top-level `MODE` wire field) and is
  /// unaffected by Advanced Config edits; there is no longer a separate
  /// `ainAType`/`ainBType` field on this class (removed 2026-09). Defaults
  /// to "None" (uninitialized) until the ESP's PAM readback populates it,
  /// matching the ESP32 gState.ainACoefType default.
  @JsonKey(name: 'AIN_A_COEF_TYPE')
  final String ainACoefType;

  /// Parameter-07 coefficient type for channel B — see [ainACoefType].
  @JsonKey(name: 'AIN_B_COEF_TYPE')
  final String ainBCoefType;

  @JsonKey(name: 'AIN_AA')
  final int ainAa;

  @JsonKey(name: 'AIN_AB')
  final int ainAb;

  @JsonKey(name: 'AIN_AC')
  final int ainAc;

  @JsonKey(name: 'AIN_BA')
  final int ainBa;

  @JsonKey(name: 'AIN_BB')
  final int ainBb;

  @JsonKey(name: 'AIN_BC')
  final int ainBc;

  @JsonKey(name: 'RAMP_A_UP')
  final int rampAaUp;

  @JsonKey(name: 'RAMP_A_DOWN')
  final int rampAaDown;

  @JsonKey(name: 'RAMP_B_UP')
  final int rampAbUp;

  @JsonKey(name: 'RAMP_B_DOWN')
  final int rampAbDown;

  @JsonKey(name: 'MIN_A')
  final int minA;

  @JsonKey(name: 'MIN_B')
  final int minB;

  @JsonKey(name: 'MAX_A')
  final int maxA;

  @JsonKey(name: 'MAX_B')
  final int maxB;

  @JsonKey(name: 'TRIGGER')
  final int trigger;

  @JsonKey(name: 'DAMPL_GLOBAL')
  final int ditherAmpGlobal;

  @JsonKey(name: 'DAMPL_A')
  final int ditherAmpA;

  @JsonKey(name: 'DAMPL_B')
  final int ditherAmpB;

  @JsonKey(name: 'DFREQ_GLOBAL')
  final int ditherFreqGlobal;

  @JsonKey(name: 'DFREQ_A')
  final int ditherFreqA;

  @JsonKey(name: 'DFREQ_B')
  final int ditherFreqB;

  @JsonKey(name: 'PWM_GLOBAL')
  final int pwmGlobal;

  @JsonKey(name: 'PWM_A')
  final int pwmA;

  @JsonKey(name: 'PWM_B')
  final int pwmB;

  @JsonKey(name: 'PPWM_GLOBAL')
  final int ppwmGlobal;

  @JsonKey(name: 'PPWM_A')
  final int ppwmA;

  @JsonKey(name: 'PPWM_B')
  final int ppwmB;

  @JsonKey(name: 'IPWM_GLOBAL')
  final int ipwmGlobal;

  @JsonKey(name: 'IPWM_A')
  final int ipwmA;

  @JsonKey(name: 'IPWM_B')
  final int ipwmB;

  const ExpConfig({
    this.sens = 'AUTO',
    this.ccMode = false,
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
    this.ppwmGlobal = 7,
    this.ppwmA = 7,
    this.ppwmB = 7,
    this.ipwmGlobal = 40,
    this.ipwmA = 40,
    this.ipwmB = 40,
  });

  factory ExpConfig.fromJson(Map<String, dynamic> json) =>
      _$ExpConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ExpConfigToJson(this);

  /// Overlays every EXP wire key present in [raw] onto [seed]. Wire keys
  /// without a mapped field (e.g. global `MIN`/`MAX`/`PPWM`/`IPWM`,
  /// `CURRENT_GLOBAL`) are intentionally ignored here — they still count as
  /// EXP-section presence for D|/L| routing via [_expGroupKeys].
  static ExpConfig fromWire(Map<String, String> raw, ExpConfig seed) {
    return ExpConfig(
      sens: _strOf(raw, 'SENS') ?? seed.sens,
      ccMode: _onOf(raw, const ['CCMODE'], seed.ccMode),
      limGlobal: _intOf(raw, const ['LIM_GLOBAL'], seed.limGlobal),
      limA: _intOf(raw, const ['LIM_A'], seed.limA),
      limB: _intOf(raw, const ['LIM_B'], seed.limB),
      polGlobal: _strOf(raw, 'POL_GLOBAL') ?? seed.polGlobal,
      polA: _strOf(raw, 'POL_A') ?? seed.polA,
      polB: _strOf(raw, 'POL_B') ?? seed.polB,

      // AIN_A_TYPE/AIN_B_TYPE are no longer sent by the ESP (removed from both
      // buildDeltaPacket() and buildFullPacket()) — always carry the seed
      // value forward. See the _cfgStringKeys comment above for details.
      ainACoefType: _strOf(raw, 'AIN_A_COEF_TYPE') ?? seed.ainACoefType,
      ainBCoefType: _strOf(raw, 'AIN_B_COEF_TYPE') ?? seed.ainBCoefType,
      ainAa: _intOf(raw, const ['AIN_AA'], seed.ainAa),
      ainAb: _intOf(raw, const ['AIN_AB'], seed.ainAb),
      ainAc: _intOf(raw, const ['AIN_AC'], seed.ainAc),
      ainBa: _intOf(raw, const ['AIN_BA'], seed.ainBa),
      ainBb: _intOf(raw, const ['AIN_BB'], seed.ainBb),
      ainBc: _intOf(raw, const ['AIN_BC'], seed.ainBc),
      rampAaUp: _intOf(raw, const ['RAMP_A_UP'], seed.rampAaUp),
      rampAaDown: _intOf(raw, const ['RAMP_A_DOWN'], seed.rampAaDown),
      rampAbUp: _intOf(raw, const ['RAMP_B_UP'], seed.rampAbUp),
      rampAbDown: _intOf(raw, const ['RAMP_B_DOWN'], seed.rampAbDown),
      minA: _intOf(raw, const ['MIN_A'], seed.minA),
      minB: _intOf(raw, const ['MIN_B'], seed.minB),
      maxA: _intOf(raw, const ['MAX_A'], seed.maxA),
      maxB: _intOf(raw, const ['MAX_B'], seed.maxB),
      trigger: _intOf(raw, const ['TRIGGER'], seed.trigger),
      ditherAmpGlobal: _intOf(raw, const [
        'DAMPL_GLOBAL',
      ], seed.ditherAmpGlobal),
      ditherAmpA: _intOf(raw, const ['DAMPL_A'], seed.ditherAmpA),
      ditherAmpB: _intOf(raw, const ['DAMPL_B'], seed.ditherAmpB),
      ditherFreqGlobal: _intOf(raw, const [
        'DFREQ_GLOBAL',
      ], seed.ditherFreqGlobal),
      ditherFreqA: _intOf(raw, const ['DFREQ_A'], seed.ditherFreqA),
      ditherFreqB: _intOf(raw, const ['DFREQ_B'], seed.ditherFreqB),
      pwmGlobal: _intOf(raw, const ['PWM_GLOBAL'], seed.pwmGlobal),
      pwmA: _intOf(raw, const ['PWM_A'], seed.pwmA),
      pwmB: _intOf(raw, const ['PWM_B'], seed.pwmB),
      ppwmGlobal: _intOf(raw, const ['PPWM_GLOBAL'], seed.ppwmGlobal),
      ppwmA: _intOf(raw, const ['PPWM_A'], seed.ppwmA),
      ppwmB: _intOf(raw, const ['PPWM_B'], seed.ppwmB),
      ipwmGlobal: _intOf(raw, const ['IPWM_GLOBAL'], seed.ipwmGlobal),
      ipwmA: _intOf(raw, const ['IPWM_A'], seed.ipwmA),
      ipwmB: _intOf(raw, const ['IPWM_B'], seed.ipwmB),
    );
  }
}

@JsonSerializable()
class MachineData {
  @JsonKey(name: 'FUNC')
  final String func;

  @JsonKey(name: 'WA')
  final double inputA;

  @JsonKey(name: 'WB')
  final double inputB;

  @JsonKey(name: 'IA')
  final double coilA;

  @JsonKey(name: 'IB')
  final double coilB;

  @JsonKey(name: 'MODE')
  final String mode;

  @JsonKey(name: 'READY')
  final String ready;

  @JsonKey(name: 'PIN15')
  final bool pin15;

  @JsonKey(name: 'PIN6')
  final bool pin6;

  @JsonKey(name: 'ENABLED_B')
  final bool enableB;

  @JsonKey(name: 'CURRENT_A')
  final double coilACurrent;

  @JsonKey(name: 'CURRENT_B')
  final double coilBCurrent;

  @JsonKey(name: 'CURRENT_S')
  final double coilCurrent;

  @JsonKey(name: 'FIRMWARE_VERSION')
  final String firmwareVersion;

  @JsonKey(name: 'ADAPTER_VOLTAGE')
  final String voltage;

  @JsonKey(name: 'TRANSITION')
  final bool transition;

  @JsonKey(name: 'PAM_CONNECTED')
  final bool pamConnected;

  /// App-preference cache (the ESP32's CONFIG_VIEW in the D|/F| protocol):
  /// "STD" or "EXP", recording which config screen was last saved from. NOT
  /// PAM's own MODE STD/EXP register (see [pamMode] for that) and NO LONGER
  /// what decides which config screen ([ConfigScreen]) is shown — that
  /// authority is [pamMode]. This field's one remaining job is internal:
  /// routing which section (std/exp) a full (F|) snapshot rebuilds fresh
  /// vs. carries forward (see the packet-merge logic below), so a save on
  /// one screen can never clobber the other screen's locally-cached values.
  /// Defaults to "STD".
  @JsonKey(name: 'CONFIG_VIEW')
  final String configView;

  /// The ACTUAL live PAM operating MODE (`PAM_MODE` wire key): "STD" or
  /// "EXP", read back from PAM's own MODE register on the ESP — and the
  /// single source of truth for which config screen ([ConfigScreen]) is
  /// shown. Changes ONLY via an explicit Basic/Advanced drawer selection
  /// (see [BleCommandController.setPamMode] / CustomDrawer's
  /// `_ConfigViewSelector`) — never automatically on connect/reconnect, and
  /// never as a side effect of saving Basic/Advanced Config parameters. This
  /// is distinct from BOTH [mode] (the AINA live V/C input type, wire key
  /// `MODE`) AND [configView] (the now UI-selection-inert app preference
  /// cache, wire key `CONFIG_VIEW`) — none of the three should ever be
  /// derived from one another. Some ESP operations (AIN coefficient
  /// read/write) temporarily switch PAM into EXP and back; the ESP only
  /// reports the settled final value here, never a transient mid-operation
  /// one. Defaults to "STD" until the first real reading arrives.
  @JsonKey(name: 'PAM_MODE')
  final String pamMode;

  /// Basic (STD) config section.
  final StdConfig stdConfig;

  /// Advanced (EXP) config section.
  final ExpConfig expConfig;

  const MachineData({
    this.func = '195',
    this.inputA = 0.0,
    this.inputB = 0.0,
    this.coilA = 0.0,
    this.coilB = 0.0,
    this.mode = '0',
    this.ready = 'ALL OFF',
    this.pin15 = false,
    this.pin6 = false,
    this.enableB = false,
    this.coilACurrent = 0.0,
    this.coilBCurrent = 0.0,
    this.coilCurrent = 0.0,
    this.firmwareVersion = '',
    this.voltage = '',
    this.transition = false,
    this.pamConnected = false,
    this.configView = _defaultConfigView,
    this.pamMode = 'STD',
    this.stdConfig = const StdConfig(),
    this.expConfig = const ExpConfig(),
  });

  // Connect to the generated factory
  factory MachineData.fromJson(Map<String, dynamic> json) =>
      _$MachineDataFromJson(json);

  // Connect to the generated generator
  Map<String, dynamic> toJson() => _$MachineDataToJson(this);

  /// Returns a copy with the given fields replaced. Only used by callers
  /// that need to flip [configView]/[stdConfig]/[expConfig] without a full
  /// packet round trip.
  MachineData copyWith({
    String? func,
    double? inputA,
    double? inputB,
    double? coilA,
    double? coilB,
    String? mode,
    String? ready,
    bool? pin15,
    bool? pin6,
    bool? enableB,
    double? coilACurrent,
    double? coilBCurrent,
    double? coilCurrent,
    String? firmwareVersion,
    String? voltage,
    bool? transition,
    bool? pamConnected,
    String? configView,
    String? pamMode,
    StdConfig? stdConfig,
    ExpConfig? expConfig,
  }) {
    return MachineData(
      func: func ?? this.func,
      inputA: inputA ?? this.inputA,
      inputB: inputB ?? this.inputB,
      coilA: coilA ?? this.coilA,
      coilB: coilB ?? this.coilB,
      mode: mode ?? this.mode,
      ready: ready ?? this.ready,
      pin15: pin15 ?? this.pin15,
      pin6: pin6 ?? this.pin6,
      enableB: enableB ?? this.enableB,
      coilACurrent: coilACurrent ?? this.coilACurrent,
      coilBCurrent: coilBCurrent ?? this.coilBCurrent,
      coilCurrent: coilCurrent ?? this.coilCurrent,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      voltage: voltage ?? this.voltage,
      transition: transition ?? this.transition,
      pamConnected: pamConnected ?? this.pamConnected,
      configView: configView ?? this.configView,
      pamMode: pamMode ?? this.pamMode,
      stdConfig: stdConfig ?? this.stdConfig,
      expConfig: expConfig ?? this.expConfig,
    );
  }

  /// Modified factory to keep your CSV-style parsing logic
  /// while utilizing the new JSON structure.
  factory MachineData.fromPacket(String packet) {
    return _parsePacketInternal(packet.trim(), null);
  }

  /// Parses a telemetry packet and merges into [current] state.
  /// Supports L| (live), D| (delta), F| (full snapshot), and legacy (no prefix).
  /// Returns the merged [MachineData] or [current] if packet is empty/malformed.
  static MachineData mergeFromPacket(String packet, MachineData current) {
    final cleanPacket = packet.trim();
    if (cleanPacket.isEmpty) return current;
    return _parsePacketInternal(cleanPacket, current);
  }

  static MachineData _parsePacketInternal(
    String cleanPacket,
    MachineData? current,
  ) {
    // Detect prefix
    String payload;
    String prefix = '';
    if (cleanPacket.startsWith('L|') ||
        cleanPacket.startsWith('D|') ||
        cleanPacket.startsWith('F|')) {
      prefix = cleanPacket.substring(0, 2);
      payload = cleanPacket.substring(2);
    } else if (cleanPacket.length >= 2 && cleanPacket[1] == '|') {
      // Unknown single-char prefix (e.g., X|) - strip it and treat as legacy
      payload = cleanPacket.substring(2);
    } else {
      // Legacy packet - full parse
      payload = cleanPacket;
    }

    // F| full snapshot replaces everything EXCEPT the config section that is
    // not the packet's active CONFIG_VIEW, which is carried forward so one
    // view saving can never clobber the other view's data.
    final isFull = prefix == 'F|';
    final currentOrNew = current ?? const MachineData();
    final rootBase = isFull ? const MachineData() : currentOrNew;

    try {
      final raw = <String, String>{};
      final parts = payload.split(',');
      for (var part in parts) {
        final kv = part.split(':');
        if (kv.length == 2 && kv[0].isNotEmpty) {
          raw[kv[0]] = kv[1];
        }
      }

      // Resolve CONFIG_VIEW: always carried by the ESP's F| builder; D|/L|
      // carry it only when DF_CONFIG_VIEW is dirty, so fall back to the
      // currently-resolved view (F| without it defaults to STD, matching the
      // pre-CONFIG_VIEW behavior of placing full snapshots in the STD view).
      final wireConfigView = raw.remove('CONFIG_VIEW');
      final configView =
          wireConfigView ?? (isFull ? _defaultConfigView : rootBase.configView);

      final stdCarry = current?.stdConfig ?? const StdConfig();
      final expCarry = current?.expConfig ?? const ExpConfig();

      final bool stdActive = isFull && configView == 'STD';
      final bool expActive = isFull && configView == 'EXP';
      final bool stdDelta = !isFull && _hasAny(raw, _stdGroupKeys);
      final bool expDelta = !isFull && _hasAny(raw, _expGroupKeys);

      // F| → rebuild the ACTIVE section fresh from the packet (seed = const
      // defaults) and carry the INACTIVE section forward untouched.
      // D|/L| → overlay whichever sections the packet's content touches
      // (content-based routing), falling back to carry for the rest.
      final stdConfig = (stdActive || stdDelta)
          ? StdConfig.fromWire(raw, stdActive ? const StdConfig() : stdCarry)
          : stdCarry;
      final expConfig = (expActive || expDelta)
          ? ExpConfig.fromWire(raw, expActive ? const ExpConfig() : expCarry)
          : expCarry;

      final result = MachineData(
        func: _strOf(raw, 'FUNC') ?? rootBase.func,
        inputA: _dblOf(raw, const ['WA'], rootBase.inputA),
        inputB: _dblOf(raw, const ['WB'], rootBase.inputB),
        coilA: _dblOf(raw, const ['IA'], rootBase.coilA),
        coilB: _dblOf(raw, const ['IB'], rootBase.coilB),
        mode: _strOf(raw, 'MODE') ?? rootBase.mode,
        ready: _strOf(raw, 'READY') ?? rootBase.ready,
        pin15: _boolOf(raw, const ['PIN15'], rootBase.pin15),
        pin6: _boolOf(raw, const ['PIN6'], rootBase.pin6),
        enableB: _boolOf(raw, const [
          'ENABLED_B',
          'ENABLE_B',
        ], rootBase.enableB),
        coilACurrent: _dblOf(raw, const [
          'CURRENT_A',
          'CURRENT_A_STATUS',
        ], rootBase.coilACurrent),
        coilBCurrent: _dblOf(raw, const [
          'CURRENT_B',
          'CURRENT_B_STATUS',
        ], rootBase.coilBCurrent),
        coilCurrent: _dblOf(raw, const [
          'CURRENT_S',
          'CURRENT_STATUS',
        ], rootBase.coilCurrent),
        firmwareVersion:
            _strOf(raw, 'FIRMWARE_VERSION') ?? rootBase.firmwareVersion,
        voltage: _strOf(raw, 'ADAPTER_VOLTAGE') ?? rootBase.voltage,
        transition: _boolOf(raw, const ['TRANSITION'], rootBase.transition),
        pamConnected: _boolOf(raw, const [
          'PAM_CONNECTED',
        ], rootBase.pamConnected),
        configView: configView,
        // Actual PAM MODE (STD/EXP) — a plain root-level scalar like
        // voltage/transition above: NOT part of the CONFIG_VIEW-routed
        // std/exp carry-forward logic, and NEVER derived from MODE (AINA
        // V/C) or from configView.
        pamMode: _strOf(raw, 'PAM_MODE') ?? rootBase.pamMode,
        stdConfig: stdConfig,
        expConfig: expConfig,
      );

      // Debug-only: parsed-packet summary + field-level diff against the
      // prior state. Fires once per packet, right after parsing — never
      // inside the D|/L| onValueReceived callback itself (that's BLE_RX).
      if (kPvcDebugProtocol) {
        // final subTag = prefix.isEmpty ? 'LEGACY' : prefix.substring(0, 1);
        // pvcTrace(
        //   'PARSE',
        //   'func=${result.func} mode=${result.mode} pamMode=${result.pamMode} '
        //       'enabledB=${result.enableB} currentA=${result.coilACurrent} '
        //       'currentB=${result.coilBCurrent} currentS=${result.coilCurrent}',
        //   sub: subTag,
        // );
        _traceMachineDataStateChanges(rootBase, result);
      }

      return result;
    } catch (e) {
      Logger().e("Parsing error: $e");
      return rootBase;
    }
  }

  /// Debug-only: logs `[APP][STATE][ms] FIELD old -> new` for exactly the
  /// fields called out in the trace spec, only when the value actually
  /// changed vs. [oldData]. No-op when [kPvcDebugProtocol] is false (see
  /// pvc_debug_trace.dart) — never affects merge/parse behavior.
  static void _traceMachineDataStateChanges(
    MachineData oldData,
    MachineData newData,
  ) {
    void t(String field, Object oldV, Object newV) {
      if (oldV != newV) pvcTrace('STATE', '$field $oldV -> $newV');
    }

    t('PAM_MODE', oldData.pamMode, newData.pamMode);
    t('MODE', oldData.mode, newData.mode);
    t('ENABLED_B', oldData.enableB, newData.enableB);
    t('CURRENT_S', oldData.coilCurrent, newData.coilCurrent);
    t('CURRENT_A', oldData.coilACurrent, newData.coilACurrent);
    t('CURRENT_B', oldData.coilBCurrent, newData.coilBCurrent);
    t('AIN_AA', oldData.expConfig.ainAa, newData.expConfig.ainAa);
    t('AIN_AB', oldData.expConfig.ainAb, newData.expConfig.ainAb);
    t('AIN_AC', oldData.expConfig.ainAc, newData.expConfig.ainAc);
    t(
      'AIN_A_COEF_TYPE',
      oldData.expConfig.ainACoefType,
      newData.expConfig.ainACoefType,
    );
    t('AIN_BA', oldData.expConfig.ainBa, newData.expConfig.ainBa);
    t('AIN_BB', oldData.expConfig.ainBb, newData.expConfig.ainBb);
    t('AIN_BC', oldData.expConfig.ainBc, newData.expConfig.ainBc);
    t(
      'AIN_B_COEF_TYPE',
      oldData.expConfig.ainBCoefType,
      newData.expConfig.ainBCoefType,
    );

    // Remaining existing D|/F| fields that were previously untraced here.
    // Same pattern as above: only fires when the stored value actually
    // changes, no normalization, no new fields — every field below already
    // exists on ExpConfig/MachineData and is already parsed by
    // ExpConfig.fromWire()/this method. ACC/PPWM/IPWM are deliberately
    // excluded — they are raw-forwarded (CMD_FORWARD_RAW) and have no
    // MachineData/D|/F| representation to diff.
    t('SENS', oldData.expConfig.sens, newData.expConfig.sens);
    t('CCMODE', oldData.expConfig.ccMode, newData.expConfig.ccMode);
    t('LIM_GLOBAL', oldData.expConfig.limGlobal, newData.expConfig.limGlobal);
    t('LIM_A', oldData.expConfig.limA, newData.expConfig.limA);
    t('LIM_B', oldData.expConfig.limB, newData.expConfig.limB);
    t('POL_GLOBAL', oldData.expConfig.polGlobal, newData.expConfig.polGlobal);
    t('POL_A', oldData.expConfig.polA, newData.expConfig.polA);
    t('POL_B', oldData.expConfig.polB, newData.expConfig.polB);
    t('RAMP_A_UP', oldData.expConfig.rampAaUp, newData.expConfig.rampAaUp);
    t(
      'RAMP_A_DOWN',
      oldData.expConfig.rampAaDown,
      newData.expConfig.rampAaDown,
    );
    t('RAMP_B_UP', oldData.expConfig.rampAbUp, newData.expConfig.rampAbUp);
    t(
      'RAMP_B_DOWN',
      oldData.expConfig.rampAbDown,
      newData.expConfig.rampAbDown,
    );
    t('MIN_A', oldData.expConfig.minA, newData.expConfig.minA);
    t('MIN_B', oldData.expConfig.minB, newData.expConfig.minB);
    t('MAX_A', oldData.expConfig.maxA, newData.expConfig.maxA);
    t('MAX_B', oldData.expConfig.maxB, newData.expConfig.maxB);
    t('TRIGGER', oldData.expConfig.trigger, newData.expConfig.trigger);
    t(
      'DAMPL_GLOBAL',
      oldData.expConfig.ditherAmpGlobal,
      newData.expConfig.ditherAmpGlobal,
    );
    t(
      'DAMPL_A',
      oldData.expConfig.ditherAmpA,
      newData.expConfig.ditherAmpA,
    );
    t(
      'DAMPL_B',
      oldData.expConfig.ditherAmpB,
      newData.expConfig.ditherAmpB,
    );
    t(
      'DFREQ_GLOBAL',
      oldData.expConfig.ditherFreqGlobal,
      newData.expConfig.ditherFreqGlobal,
    );
    t(
      'DFREQ_A',
      oldData.expConfig.ditherFreqA,
      newData.expConfig.ditherFreqA,
    );
    t(
      'DFREQ_B',
      oldData.expConfig.ditherFreqB,
      newData.expConfig.ditherFreqB,
    );
    t('PWM_GLOBAL', oldData.expConfig.pwmGlobal, newData.expConfig.pwmGlobal);
    t('PWM_A', oldData.expConfig.pwmA, newData.expConfig.pwmA);
    t('PWM_B', oldData.expConfig.pwmB, newData.expConfig.pwmB);
    t('CONFIG_VIEW', oldData.configView, newData.configView);
  }
}
