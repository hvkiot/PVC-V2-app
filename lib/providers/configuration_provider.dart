import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- CONFIGURATION TAB STATE ---
class ConfigTabState {
  final double coilCurrent; // For Mode 195
  final double coilACurrent; // For Mode 196
  final double coilBCurrent; // For Mode 196
  final bool isSeeded; // True once hardware values have been bridged in

  const ConfigTabState({
    this.coilCurrent = 0.0,
    this.coilACurrent = 0.0,
    this.coilBCurrent = 0.0,
    this.isSeeded = false,
  });

  ConfigTabState copyWith({
    double? coilCurrent,
    double? coilACurrent,
    double? coilBCurrent,
    bool? isSeeded,
  }) {
    return ConfigTabState(
      coilCurrent: coilCurrent ?? this.coilCurrent,
      coilACurrent: coilACurrent ?? this.coilACurrent,
      coilBCurrent: coilBCurrent ?? this.coilBCurrent,
      isSeeded: isSeeded ?? this.isSeeded,
    );
  }
}

// StateNotifier for Configuration Tab
class ConfigTabNotifier extends StateNotifier<ConfigTabState> {
  ConfigTabNotifier() : super(const ConfigTabState());

  void setCoilCurrent(double value) {
    state = state.copyWith(coilCurrent: value);
  }

  void setCoilACurrent(double value) {
    state = state.copyWith(coilACurrent: value);
  }

  void setCoilBCurrent(double value) {
    state = state.copyWith(coilBCurrent: value);
  }

  // Inside ConfigTabNotifier
  void handleModeChange() {
    // Clear the seed so the UI is forced to accept
    // the new 1000mA defaults from the next hardware packet.
    state = state.copyWith(isSeeded: false);
  }

  /// One-way bridge: seed from hardware values.
  /// Once seeded, this will not be called again until after a Save or Reset.
  void seedFromHardware(double coil, double coilA, double coilB) {
    state = state.copyWith(
      coilCurrent: coil,
      coilACurrent: coilA,
      coilBCurrent: coilB,
      isSeeded: true,
    );
  }

  /// Full reset after a successful Save — clears the draft and re-seeds.
  void reset(double coil, double coilA, double coilB) {
    state = ConfigTabState(
      coilCurrent: coil,
      coilACurrent: coilA,
      coilBCurrent: coilB,
      isSeeded: true, // This tells the UI to stop showing old draft values
    );
  }

  /// Mark as un-seeded (e.g. on reconnection or explicit user reset).
  void clearSeed() {
    state = const ConfigTabState();
  }
}

final configTabProvider =
    StateNotifierProvider<ConfigTabNotifier, ConfigTabState>((ref) {
      return ConfigTabNotifier();
    });

// --- INPUTS TAB STATE ---
class InputsTabState {
  final String? selectedMode;
  final String? selectedInput1;
  final String? selectedInput2;

  const InputsTabState({
    this.selectedMode,
    this.selectedInput1,
    this.selectedInput2,
  });

  InputsTabState copyWith({
    String? selectedMode,
    String? selectedInput1,
    String? selectedInput2,
  }) {
    return InputsTabState(
      selectedMode: selectedMode ?? this.selectedMode,
      selectedInput1: selectedInput1 ?? this.selectedInput1,
      selectedInput2: selectedInput2 ?? this.selectedInput2,
    );
  }
}

// StateNotifier for Inputs Tab
class InputsTabNotifier extends StateNotifier<InputsTabState> {
  InputsTabNotifier() : super(const InputsTabState());

  void setMode(String value) {
    state = state.copyWith(selectedMode: value);
  }

  void setInput1(String value) {
    state = state.copyWith(selectedInput1: value);
  }

  void setInput2(String value) {
    state = state.copyWith(selectedInput2: value);
  }

  void reset() {
    state = const InputsTabState();
  }
}

final inputsTabProvider =
    StateNotifierProvider<InputsTabNotifier, InputsTabState>((ref) {
      return InputsTabNotifier();
    });
