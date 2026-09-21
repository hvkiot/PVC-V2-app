import 'package:flutter/foundation.dart';

// ============================================================
// pvc_debug_trace.dart — DEBUG-ONLY end-to-end protocol trace
// ------------------------------------------------------------
// Mirrors PVC_DEBUG_PROTOCOL on the ESP32 side (see config.h /
// log_bridge.h in the firmware). Logging-only: when [kPvcDebugProtocol]
// is false, pvcTrace() is a no-op — no timing/behavior/protocol impact.
// Flip the default below (or pass --dart-define=PVC_DEBUG_PROTOCOL=true)
// only for bench debugging.
//
// Timestamps are ms-since-process-start from a monotonic Stopwatch — no
// wall-clock formatting, matching the ESP side's millis(). Only ordering
// relative to the ESP trace (and other app trace lines) matters.
//
// Format: [APP][TAG][ms] message
//         [APP][TAG][ms][SUB] message   (e.g. BLE_TX/PARSE with D/F/L)
// ============================================================

const bool kPvcDebugProtocol = bool.fromEnvironment(
  'PVC_DEBUG_PROTOCOL',
  defaultValue: false,
);

final Stopwatch _pvcTraceClock = Stopwatch()..start();

/// Logging-only debug trace. No-op (does not even format the message)
/// when [kPvcDebugProtocol] is false.
void pvcTrace(String tag, String msg, {String? sub}) {
  if (!kPvcDebugProtocol) return;
  final ms = _pvcTraceClock.elapsedMilliseconds;
  if (sub != null) {
    debugPrint('[APP][$tag][$ms][$sub] $msg');
  } else {
    debugPrint('[APP][$tag][$ms] $msg');
  }
}
