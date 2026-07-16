// core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  /// AgePay brand green. Stays constant across light, dark, and system themes.
  static const Color brandGreen = Color.fromARGB(255, 9, 52, 19);

  static ThemeData get lightTheme {
    return ThemeData(
      colorSchemeSeed: brandGreen,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      colorSchemeSeed: brandGreen,
      useMaterial3: true,
      brightness: Brightness.dark,
    );
  }
}
