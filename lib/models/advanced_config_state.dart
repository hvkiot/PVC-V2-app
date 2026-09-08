import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Parameter metadata
// ---------------------------------------------------------------------------

enum ParamGroup { general, standard, expert }

class ParamDef {
  final String id;
  final String name;
  final String command;
  final ParamGroup group;

  const ParamDef({
    required this.id,
    required this.name,
    required this.command,
    required this.group,
  });
}

const List<ParamDef> kParamDefs = [
  ParamDef(id: '01', name: 'Function', command: 'FUNCTION', group: ParamGroup.general),
  ParamDef(id: '02', name: 'SENS', command: 'SENS', group: ParamGroup.standard),
  ParamDef(id: '03', name: 'CC Mode', command: 'CCMODE', group: ParamGroup.expert),
  ParamDef(id: '04', name: 'Enable-B', command: 'ENABLE_B', group: ParamGroup.expert),
  ParamDef(id: '05', name: 'LIMIT', command: 'LIM', group: ParamGroup.expert),
  ParamDef(id: '06', name: 'POL', command: 'POL', group: ParamGroup.standard),
  ParamDef(id: '07', name: 'AIN', command: 'AIN', group: ParamGroup.expert),
  ParamDef(id: '08', name: 'Ramp', command: 'AA/AB', group: ParamGroup.standard),
  ParamDef(id: '09', name: 'MIN', command: 'MIN', group: ParamGroup.standard),
  ParamDef(id: '10', name: 'MAX', command: 'MAX', group: ParamGroup.standard),
  ParamDef(id: '11', name: 'Trigger', command: 'TRIGGER', group: ParamGroup.standard),
  ParamDef(id: '12', name: 'Dither Amplitude', command: 'DAMPL', group: ParamGroup.standard),
  ParamDef(id: '13', name: 'Dither Frequency', command: 'DFREQ', group: ParamGroup.standard),
  ParamDef(id: '14', name: 'PWM Frequency', command: 'PWM', group: ParamGroup.expert),
  ParamDef(id: '15', name: 'Current', command: 'CURRENT', group: ParamGroup.standard),
];

// ---------------------------------------------------------------------------
// Local draft state — UI-only, not wired to BLE yet
// ---------------------------------------------------------------------------

class AdvancedConfigState {
  final String selectedParam;
  final String func;
  final bool ainAdvancedTab;
  final bool accOn;

  // Per-parameter local drafts
  final String sens;
  final bool ccMode;
  final bool enableB;
  final int limGlobal;
  final int limA;
  final int limB;
  final String polGlobal;
  final String polA;
  final String polB;
  final String ainAType;
  final String ainBType;
  final int ainAa;
  final int ainAb;
  final int ainAc;
  final int ainBa;
  final int ainBb;
  final int ainBc;
  final int rampAaUp;
  final int rampAaDown;
  final int rampAbUp;
  final int rampAbDown;
  final int minA;
  final int minB;
  final int maxA;
  final int maxB;
  final int trigger;
  final int ditherAmpGlobal;
  final int ditherAmpA;
  final int ditherAmpB;
  final int ditherFreqGlobal;
  final int ditherFreqA;
  final int ditherFreqB;
  final int pwmGlobal;
  final int pwmA;
  final int pwmB;
  final int ppwmGlobal;
  final int ppwmA;
  final int ppwmB;
  final int ipwmGlobal;
  final int ipwmA;
  final int ipwmB;
  final int currentGlobal;
  final int currentA;
  final int currentB;

  const AdvancedConfigState({
    this.selectedParam = '01',
    this.func = '195',
    this.ainAdvancedTab = false,
    this.accOn = true,
    this.sens = 'AUTO',
    this.ccMode = false,
    this.enableB = false,
    this.limGlobal = 0,
    this.limA = 0,
    this.limB = 0,
    this.polGlobal = '+',
    this.polA = '+',
    this.polB = '+',
    this.ainAType = 'V',
    this.ainBType = 'V',
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
    this.currentGlobal = 1000,
    this.currentA = 1000,
    this.currentB = 1000,
  });

  AdvancedConfigState copyWith({
    String? selectedParam,
    String? func,
    bool? ainAdvancedTab,
    bool? accOn,
    String? sens,
    bool? ccMode,
    bool? enableB,
    int? limGlobal,
    int? limA,
    int? limB,
    String? polGlobal,
    String? polA,
    String? polB,
    String? ainAType,
    String? ainBType,
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
    int? ppwmGlobal,
    int? ppwmA,
    int? ppwmB,
    int? ipwmGlobal,
    int? ipwmA,
    int? ipwmB,
    int? currentGlobal,
    int? currentA,
    int? currentB,
  }) {
    return AdvancedConfigState(
      selectedParam: selectedParam ?? this.selectedParam,
      func: func ?? this.func,
      ainAdvancedTab: ainAdvancedTab ?? this.ainAdvancedTab,
      accOn: accOn ?? this.accOn,
      sens: sens ?? this.sens,
      ccMode: ccMode ?? this.ccMode,
      enableB: enableB ?? this.enableB,
      limGlobal: limGlobal ?? this.limGlobal,
      limA: limA ?? this.limA,
      limB: limB ?? this.limB,
      polGlobal: polGlobal ?? this.polGlobal,
      polA: polA ?? this.polA,
      polB: polB ?? this.polB,
      ainAType: ainAType ?? this.ainAType,
      ainBType: ainBType ?? this.ainBType,
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
      ppwmGlobal: ppwmGlobal ?? this.ppwmGlobal,
      ppwmA: ppwmA ?? this.ppwmA,
      ppwmB: ppwmB ?? this.ppwmB,
      ipwmGlobal: ipwmGlobal ?? this.ipwmGlobal,
      ipwmA: ipwmA ?? this.ipwmA,
      ipwmB: ipwmB ?? this.ipwmB,
      currentGlobal: currentGlobal ?? this.currentGlobal,
      currentA: currentA ?? this.currentA,
      currentB: currentB ?? this.currentB,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AdvancedConfigNotifier extends StateNotifier<AdvancedConfigState> {
  AdvancedConfigNotifier() : super(const AdvancedConfigState());

  void selectParam(String id) => state = state.copyWith(selectedParam: id);

  void setFunc(String value) => state = state.copyWith(func: value);

  void toggleAinAdvancedTab() =>
      state = state.copyWith(ainAdvancedTab: !state.ainAdvancedTab);

  void toggleAcc() => state = state.copyWith(accOn: !state.accOn);

  void setSens(String value) => state = state.copyWith(sens: value);

  void setCcMode(bool value) => state = state.copyWith(ccMode: value);

  void setEnableB(bool value) => state = state.copyWith(enableB: value);

  void setLimGlobal(int value) => state = state.copyWith(limGlobal: value);

  void setLimA(int value) => state = state.copyWith(limA: value);

  void setLimB(int value) => state = state.copyWith(limB: value);

  void setPolGlobal(String value) => state = state.copyWith(polGlobal: value);

  void setPolA(String value) => state = state.copyWith(polA: value);

  void setPolB(String value) => state = state.copyWith(polB: value);

  void setAinAType(String value) => state = state.copyWith(ainAType: value);

  void setAinBType(String value) => state = state.copyWith(ainBType: value);

  void setAinAa(int value) => state = state.copyWith(ainAa: value);

  void setAinAb(int value) => state = state.copyWith(ainAb: value);

  void setAinAc(int value) => state = state.copyWith(ainAc: value);

  void setAinBa(int value) => state = state.copyWith(ainBa: value);

  void setAinBb(int value) => state = state.copyWith(ainBb: value);

  void setAinBc(int value) => state = state.copyWith(ainBc: value);

  void setRampAaUp(int value) => state = state.copyWith(rampAaUp: value);

  void setRampAaDown(int value) => state = state.copyWith(rampAaDown: value);

  void setRampAbUp(int value) => state = state.copyWith(rampAbUp: value);

  void setRampAbDown(int value) => state = state.copyWith(rampAbDown: value);

  void setMinA(int value) => state = state.copyWith(minA: value);

  void setMinB(int value) => state = state.copyWith(minB: value);

  void setMaxA(int value) => state = state.copyWith(maxA: value);

  void setMaxB(int value) => state = state.copyWith(maxB: value);

  void setTrigger(int value) => state = state.copyWith(trigger: value);

  void setDitherAmpGlobal(int value) =>
      state = state.copyWith(ditherAmpGlobal: value);

  void setDitherAmpA(int value) => state = state.copyWith(ditherAmpA: value);

  void setDitherAmpB(int value) => state = state.copyWith(ditherAmpB: value);

  void setDitherFreqGlobal(int value) =>
      state = state.copyWith(ditherFreqGlobal: value);

  void setDitherFreqA(int value) => state = state.copyWith(ditherFreqA: value);

  void setDitherFreqB(int value) => state = state.copyWith(ditherFreqB: value);

  void setPwmGlobal(int value) => state = state.copyWith(pwmGlobal: value);

  void setPwmA(int value) => state = state.copyWith(pwmA: value);

  void setPwmB(int value) => state = state.copyWith(pwmB: value);

  void setPpwmGlobal(int value) => state = state.copyWith(ppwmGlobal: value);

  void setPpwmA(int value) => state = state.copyWith(ppwmA: value);

  void setPpwmB(int value) => state = state.copyWith(ppwmB: value);

  void setIpwmGlobal(int value) => state = state.copyWith(ipwmGlobal: value);

  void setIpwmA(int value) => state = state.copyWith(ipwmA: value);

  void setIpwmB(int value) => state = state.copyWith(ipwmB: value);

  void setCurrentGlobal(int value) =>
      state = state.copyWith(currentGlobal: value);

  void setCurrentA(int value) => state = state.copyWith(currentA: value);

  void setCurrentB(int value) => state = state.copyWith(currentB: value);
}

final advancedConfigProvider =
    StateNotifierProvider<AdvancedConfigNotifier, AdvancedConfigState>((ref) {
      return AdvancedConfigNotifier();
    });
