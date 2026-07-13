import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF2FB4A6);
  // LIGHT THEME
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFB),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE2E7E9),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8FAFB),
      foregroundColor: Color(0xFF1E2A35),
      elevation: 0,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(primaryColor),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor.withOpacity(0.4);
        }
        return Colors.grey.shade300;
      }),
    ),
  );

  // DARK THEME
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    dividerColor: const Color(0xFF303030),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(primaryColor),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor.withOpacity(0.5);
        }
        return Colors.grey;
      }),
    ),
  );
}