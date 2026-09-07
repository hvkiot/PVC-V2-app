/// Names the ENABLE pin(s) currently holding the device active/locked.
/// Used to guide the user on which pin to release before editing.
String activePinsLabel(bool pin15, bool pin6) {
  if (pin15 && pin6) return "Pin 15 and Pin 6";
  if (pin15) return "Pin 15";
  return "Pin 6";
}
