// core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  /// AgePay brand green (deep forest green for light theme).
  static const Color brandGreen = Color.fromARGB(255, 9, 52, 19);

  /// High-contrast emerald green for dark theme elements.
  static const Color brandGreenLight = Color(0xFF66BB6A);

  /// Returns brand green in light mode, and high-contrast green in dark mode.
  static Color primary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? brandGreenLight
        : brandGreen;
  }

  /// Returns a soft translucent container background tinted with brand green.
  static Color primaryContainer(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? brandGreenLight.withValues(alpha: 0.18)
        : brandGreen.withValues(alpha: 0.1);
  }

  /// Returns high-contrast text color on standard card/scaffold surface.
  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// Returns secondary muted text color on standard surface.
  static Color onSurfaceVariant(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// Returns subtle card or divider border color for light / dark surfaces.
  static Color cardBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white12
        : Colors.grey.shade200;
  }

  /// Returns an accessible foreground text/icon color for status tags.
  static Color statusColor(BuildContext context, MaterialColor color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? (color[300] ?? color) : (color[900] ?? color[800] ?? color);
  }

  /// Returns a non-glaring background tint for status tags and alert boxes.
  static Color statusBg(BuildContext context, MaterialColor color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? color.withValues(alpha: 0.22)
        : (color[50] ?? color.withValues(alpha: 0.1));
  }

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
    final base = ThemeData(
      colorSchemeSeed: brandGreen,
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF111513),
      colorScheme: base.colorScheme.copyWith(
        primary: brandGreenLight,
        surface: const Color(0xFF181E1A),
        onSurface: const Color(0xFFE8ECE9),
        onSurfaceVariant: const Color(0xFFA6B0A8),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF111513),
        foregroundColor: Color(0xFFE8ECE9),
        iconTheme: IconThemeData(color: brandGreenLight),
        actionsIconTheme: IconThemeData(color: brandGreenLight),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1C2420),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Colors.white12),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color(0xFF1E2622),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Colors.white12),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF1C2420),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1C2420),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.white12,
        thickness: 1,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Colors.white10,
        side: BorderSide.none,
      ),
    );
  }
}

extension AppThemeContextX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get brandGreen => AppTheme.primary(this);
  Color get brandGreenTint => AppTheme.primaryContainer(this);
  Color get onSurface => Theme.of(this).colorScheme.onSurface;
  Color get onSurfaceVariant => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get cardBorderColor => AppTheme.cardBorder(this);
}
