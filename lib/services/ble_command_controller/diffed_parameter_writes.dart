part of '../ble_command_controller.dart';

/// Param 05/06/09/10/12/13/14 — per-channel EXP writes that share the same
/// diffing shape: compare the draft value(s) against the current
/// [MachineData] `expConfig` baseline and send only what actually changed
/// (neither changed → no command, one changed → that channel's existing
/// single command, both changed → one grouped command). Mode 195 (global)
/// params use a single value with no diffing branch.
mixin _DiffedParameterWrites {
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
}
