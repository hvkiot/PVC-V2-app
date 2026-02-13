import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // Shared button style to prevent "inherit" property crashes
  static const TextStyle _sharedButtonTextStyle = TextStyle(
    inherit: true,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.1,
  );

  // --- LIGHT THEME (Primary: Brand Red) ---
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.brandRed, // Light Theme Primary
      secondary: AppColors.brandBlue,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
    ),

    textTheme: const TextTheme(labelLarge: _sharedButtonTextStyle),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.brandRed,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        inherit: true,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.brandRed,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandRed,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: _sharedButtonTextStyle,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.brandRed, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: _sharedButtonTextStyle.copyWith(color: AppColors.brandRed),
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),

    listTileTheme: ListTileThemeData(
      tileColor: AppColors.lightSurface,
      iconColor: AppColors.brandRed,
      selectedColor: AppColors.brandRed,
      selectedTileColor: AppColors.brandRed.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.brandRed,
      unselectedItemColor: AppColors.lightTextSecondary,
      selectedLabelStyle: const TextStyle(
        inherit: true, // Prevents the interpolation crash
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(inherit: true, fontSize: 12),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );

  // --- DARK THEME (Primary: Brand Cyan) ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.brandCyan, // Dark Theme Primary
      secondary: AppColors.brandRed,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
    ),

    textTheme: const TextTheme(labelLarge: _sharedButtonTextStyle),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.brandCyan,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        inherit: true,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.brandCyan,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandCyan,
        foregroundColor:
            AppColors.brandBlue, // Dark Navy text on Cyan looks sharp
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: _sharedButtonTextStyle,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.brandCyan, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: _sharedButtonTextStyle.copyWith(color: AppColors.brandCyan),
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
    ),

    listTileTheme: ListTileThemeData(
      tileColor: AppColors.darkSurface,
      iconColor: AppColors.brandCyan,
      selectedColor: AppColors.brandCyan,
      selectedTileColor: AppColors.brandCyan.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.brandCyan,
      unselectedItemColor: AppColors.darkTextSecondary,
      selectedLabelStyle: const TextStyle(
        inherit: true, // Prevents the interpolation crash
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(inherit: true, fontSize: 12),
      type: BottomNavigationBarType.fixed,
      elevation: 0, // Keeps it flat and minimalist for dark mode
    ),
  );
}
