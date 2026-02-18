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
      primary: AppColors.brandRed,
      secondary: AppColors.brandBlue,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
      primaryContainer: Color(
        0xFFFCE4EC,
      ), // Light pink tint for icon backgrounds
      onSurfaceVariant: Color(0xFF5F5F5F), // Muted label text
      error: Color(0xFFD32F2F),
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

    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFFE8EAF0), // surfaceVariant equivalent
      contentTextStyle: const TextStyle(
        inherit: true,
        color: AppColors.lightText,
        fontWeight: FontWeight.bold,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.brandRed, width: 1),
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.brandRed,
      unselectedItemColor: AppColors.lightTextSecondary,
      selectedLabelStyle: const TextStyle(
        inherit: true,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(inherit: true, fontSize: 12),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      focusedBorder: InputBorder.none,
      enabledBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
  );

  // --- DARK THEME (Primary: Brand Cyan) ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.brandCyan,
      secondary: AppColors.brandRed,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      primaryContainer: Color(
        0xFF0A2A3C,
      ), // Dark teal tint for icon backgrounds
      onSurfaceVariant: Color(0xFF9E9E9E), // Muted label text
      error: AppColors.mutedErrorRed,
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

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkSurface,
      contentTextStyle: const TextStyle(
        inherit: true,
        color: AppColors.darkText,
        fontWeight: FontWeight.bold,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.brandCyan, width: 1),
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.brandCyan,
      unselectedItemColor: AppColors.darkTextSecondary,
      selectedLabelStyle: const TextStyle(
        inherit: true,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(inherit: true, fontSize: 12),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      focusedBorder: InputBorder.none,
      enabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
  );
}
