import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- CONFIGURATION TAB STATE ---
class ConfigTabState {
  final String coilCurrent; // For Mode 195
  final String coilACurrent; // For Mode 196
  final String coilBCurrent; // For Mode 196

  const ConfigTabState({
    this.coilCurrent = '0.0',
    this.coilACurrent = '0.0',
    this.coilBCurrent = '0.0',
  });

  ConfigTabState copyWith({
    String? coilCurrent,
    String? coilACurrent,
    String? coilBCurrent,
  }) {
    return ConfigTabState(
      coilCurrent: coilCurrent ?? this.coilCurrent,
      coilACurrent: coilACurrent ?? this.coilACurrent,
      coilBCurrent: coilBCurrent ?? this.coilBCurrent,
    );
  }
}

// StateNotifier for Configuration Tab
class ConfigTabNotifier extends StateNotifier<ConfigTabState> {
  ConfigTabNotifier() : super(const ConfigTabState());

  void setCoilCurrent(String value) {
    state = state.copyWith(coilCurrent: value);
  }

  void setCoilACurrent(String value) {
    state = state.copyWith(coilACurrent: value);
  }

  void setCoilBCurrent(String value) {
    state = state.copyWith(coilBCurrent: value);
  }

  // Reset to machine values
  void reset(String coil, String coilA, String coilB) {
    state = ConfigTabState(
      coilCurrent: coil,
      coilACurrent: coilA,
      coilBCurrent: coilB,
    );
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
