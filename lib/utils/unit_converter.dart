class UnitConverter {
  /// Converts milliamperes to amperes
  static double toAmps(double mA) {
    return mA / 1000.0;
  }

  /// Converts amperes to milliamperes
  static double toMAmps(double amps) {
    return amps * 1000.0;
  }

  /// Formats a value for display with 1 decimal place
  static String format(double value) {
    return value.toStringAsFixed(1);
  }
}
