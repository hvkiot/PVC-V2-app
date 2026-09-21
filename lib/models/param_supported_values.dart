/// Static supported-value lists for parameters whose PAM read/write domain
/// is a fixed discrete set rather than a free 1-unit-step range.
///
/// Referenced from `ParamDef.supportedValues` in
/// `screens/navigate_screens/advanced_config_screen.dart` — kept in this
/// separate file (rather than inline in that screen) so the UI consumes the
/// data instead of hard-coding it.
library;

// ---------------------------------------------------------------------------
// Parameter 13 — Dither Frequency (DFREQ)
// ---------------------------------------------------------------------------
// PAM's DFREQ register only accepts/returns one of exactly 57 discrete
// frequency values — it is NOT a continuous 1 Hz field. Confirmed by a full
// 60-400 Hz hardware sweep: every requested value in that range snapped to
// one of the 57 values below on readback (e.g. 124 -> 125, 130 -> 133), and
// the sweep produced exactly these 57 unique values with no others. PAM
// itself performs the snap — Flutter must only ever send one of these 57
// exact values, with no rounding/snapping logic of its own.
const List<int> kDitherFrequencySupportedValues = [
  60, 61, 62, 63, 64, 65, 66, 67, 68, 70,
  71, 72, 74, 75, 76, 78, 80, 81, 83, 85,
  86, 88, 90, 93, 95, 97, 100, 102, 105, 108,
  111, 114, 117, 121, 125, 129, 133, 137, 142, 148,
  153, 160, 166, 173, 181, 190, 200, 210, 222, 235,
  250, 266, 285, 307, 333, 363, 400,
];
