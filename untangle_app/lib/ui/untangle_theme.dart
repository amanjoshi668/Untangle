import 'package:flutter/material.dart';
import '../models/decision_model.dart';

class UntangleTheme {
  static const Color brassLight = Color(0xFF9A6F1E);
  static const Color goldDark = Color(0xFFD4A853);
  static const Color paper = Color(0xFFFAF8F5);
  static const Color heroStart = Color(0xFF1E1A15);
  static const Color heroEnd = Color(0xFF3B2F1E);

  /// Serif display family — gives Untangle its editorial, book-like character.
  static const String displayFamily = 'serif';

  /// Each of the four book sections gets its own identity color.
  static Color sectionColor(BookSection s, Brightness b) {
    final dark = b == Brightness.dark;
    switch (s) {
      case BookSection.improveSelf:
        return dark ? const Color(0xFFE08A62) : const Color(0xFFC4613A); // terracotta
      case BookSection.understandSelf:
        return dark ? const Color(0xFF8DBF98) : const Color(0xFF4F8560); // sage
      case BookSection.understandOthers:
        return dark ? const Color(0xFF8FA6DE) : const Color(0xFF4F6AA8); // slate indigo
      case BookSection.improveOthers:
        return dark ? const Color(0xFFC493C2) : const Color(0xFF8E5A8C); // plum
    }
  }

  static TextStyle display(BuildContext context, {double size = 22, Color? color}) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  static TextStyle eyebrow(Color color) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
        color: color,
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        bg: const Color(0xFFF7F3EC),
        surface: const Color(0xFFFFFFFF),
        ink: const Color(0xFF1C1917),
        muted: const Color(0xFF78716C),
        border: const Color(0xFFE8E1D6),
        primary: brassLight,
        onPrimary: Colors.white,
        secondary: const Color(0xFFF1EBE1),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        bg: const Color(0xFF121214),
        surface: const Color(0xFF1C1C20),
        ink: const Color(0xFFF5F5F4),
        muted: const Color(0xFFA8A29E),
        border: const Color(0xFF2E2E34),
        primary: goldDark,
        onPrimary: const Color(0xFF18181B),
        secondary: const Color(0xFF26262B),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color ink,
    required Color muted,
    required Color border,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
  }) {
    final scheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: primary,
            onPrimary: onPrimary,
            secondary: secondary,
            onSecondary: ink,
            surface: surface,
            onSurface: ink,
            outline: border,
          )
        : ColorScheme.light(
            primary: primary,
            onPrimary: onPrimary,
            secondary: secondary,
            onSecondary: ink,
            surface: surface,
            onSurface: ink,
            outline: border,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      dividerColor: border,
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        isDense: true,
        hintStyle: TextStyle(color: muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: border,
        thumbColor: primary,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.3),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.2),
        bodyMedium: TextStyle(fontSize: 13.5, color: ink, height: 1.45),
        bodySmall: TextStyle(fontSize: 12, color: muted, height: 1.4),
      ),
    );
  }
}
