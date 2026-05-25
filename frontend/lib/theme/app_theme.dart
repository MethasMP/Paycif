import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - New Design System (Teal & Gold)
  static const Color primaryTeal = Color(0xFF0F6E56);
  static const Color primaryTealDark = Color(0xFF085041);
  static const Color primaryTealLight = Color(0xFFE1F5EE);
  
  static const Color accentGold = Color(0xFFEF9F27);
  static const Color accentGoldDisabled = Color(0xFFFAC775);
  static const Color accentGoldDark = Color(0xFF412402);

  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color backgroundGrey = Color(0xFFF7F7F5);
  static const Color backgroundTealTint = Color(0xFFF0FAF5);

  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF666664);
  static const Color textPlaceholder = Color(0xFFAAAAAA);

  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);

  // Text Theme (Material 3 Typography)
  static TextTheme _buildTextTheme(ThemeData base) {
    return GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.inter(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25),
      displayMedium: GoogleFonts.inter(fontSize: 45, fontWeight: FontWeight.w400, letterSpacing: 0),
      displaySmall: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w400, letterSpacing: 0),
      headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w400, letterSpacing: 0),
      headlineMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w400, letterSpacing: 0),
      headlineSmall: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: 0),
      titleLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
      titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      primaryColor: primaryTeal,
      scaffoldBackgroundColor: backgroundGrey,
      cardColor: backgroundWhite,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        primary: primaryTeal,
        secondary: accentGold,
        surface: backgroundWhite,
        error: errorRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
      ),
      textTheme: _buildTextTheme(base).apply(bodyColor: textPrimary, displayColor: textPrimary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGold,
          foregroundColor: accentGoldDark,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        color: backgroundWhite,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryTeal, width: 2)),
        hintStyle: const TextStyle(color: textPlaceholder),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    const Color darkBg = Color(0xFF04342C); // Base dark mode from design
    const Color surfaceColor = Color(0xFF085041); // Surface dark mode from design

    return base.copyWith(
      primaryColor: accentGold,
      scaffoldBackgroundColor: darkBg,
      cardColor: surfaceColor,
      colorScheme: base.colorScheme.copyWith(
        primary: accentGold,
        onPrimary: accentGoldDark,
        surface: surfaceColor,
        onSurface: Colors.white,
        error: errorRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
      ),
      textTheme: _buildTextTheme(base).apply(bodyColor: Colors.white, displayColor: Colors.white),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGold,
          foregroundColor: accentGoldDark,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        color: surfaceColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentGold, width: 2)),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      ),
    );
  }
}
