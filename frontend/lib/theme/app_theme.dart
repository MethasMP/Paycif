import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - New Design System (Teal & Gold)
  static const Color primaryTeal = Color(0xFF00A896); // primary-500
  static const Color primaryTealDark = Color(0xFF005D53); // primary-800
  static const Color primaryTealLight = Color(0xFFE6F7F5); // primary-50
  
  static const Color accentGold = Color(0xFFF4B41A); // accent-500
  static const Color accentGoldDisabled = Color(0xFFFBD983); // accent-300
  static const Color accentGoldDark = Color(0xFF745100); // accent-900

  static const Color backgroundWhite = Color(0xFFFFFFFF); // bg-primary
  static const Color backgroundGrey = Color(0xFFF8FAFC); // bg-secondary
  static const Color borderGrey = Color(0xFFE2E8F0); // border

  static const Color textPrimary = Color(0xFF0F172A); // text-primary
  static const Color textSecondary = Color(0xFF64748B); // text-secondary
  static const Color textPlaceholder = Color(0xFF94A3B8); // text-tertiary

  // Semantic
  static const Color errorRed = Color(0xFFEF4444); // error default
  static const Color successGreen = Color(0xFF10B981); // success default
  static const Color warningAmber = Color(0xFFF59E0B); // warning default
  static const Color infoBlue = Color(0xFF3B82F6); // info

  static Color textPrimaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF5F5F5) : textPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.white70 : textSecondary;

  static Color primaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2BBF9E) : primaryTeal;

  // Text Theme (Material 3 Typography mapped to Design System Scale)
  static TextTheme _buildTextTheme(ThemeData base) {
    final String? thaiFontFamily = GoogleFonts.ibmPlexSansThai().fontFamily;
    final thaiFallback = thaiFontFamily != null ? [thaiFontFamily] : <String>[];
    
    return GoogleFonts.ibmPlexSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.ibmPlexSans(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 1.5,
        color: const Color(0xFF028090), // primary.900
        fontFeatures: const [FontFeature.tabularFigures()],
      ).copyWith(fontFamilyFallback: thaiFallback), // display: 48/57, 700, tnum
      headlineLarge: GoogleFonts.ibmPlexSans(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.3,
      ).copyWith(fontFamilyFallback: thaiFallback), // H1: 32, 600
      headlineMedium: GoogleFonts.ibmPlexSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.2,
      ).copyWith(fontFamilyFallback: thaiFallback), // H2: 24, 600
      headlineSmall: GoogleFonts.ibmPlexSans(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ).copyWith(fontFamilyFallback: thaiFallback), // H3: 20, 500
      bodyLarge: GoogleFonts.ibmPlexSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ).copyWith(fontFamilyFallback: thaiFallback), // bodyLg: 16, 400
      bodyMedium: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ).copyWith(fontFamilyFallback: thaiFallback), // body: 14, 400
      bodySmall: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.2,
      ).copyWith(fontFamilyFallback: thaiFallback), // caption: 12, 500
      labelLarge: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ).copyWith(fontFamilyFallback: thaiFallback),
      labelSmall: GoogleFonts.ibmPlexSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ).copyWith(fontFamilyFallback: thaiFallback),
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      primaryColor: primaryTeal,
      scaffoldBackgroundColor: const Color(0xFFFBFBFA),
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
        centerTitle: false,
      ),
      textTheme: _buildTextTheme(base).apply(bodyColor: textPrimary, displayColor: textPrimary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGold,
          foregroundColor: accentGoldDark,
          elevation: 1, // Soft shadow elevation 1 for gold CTA
          shadowColor: primaryTeal.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTeal,
          side: const BorderSide(color: primaryTeal, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondary,
          textStyle: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))), // Corner radius 12px for cards
        color: backgroundGrey,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundGrey,
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
    const Color darkBg = Color(0xFF0B0F0E); // bg
    const Color surfaceColor = Color(0xFF141A18); // surface
    const Color darkPrimary = Color(0xFF2BBF9E); // primary
    const Color darkAccent = Color(0xFFFAC775); // accent
    const Color darkTextPrimary = Color(0xFFF5F5F5); // text-primary

    return base.copyWith(
      primaryColor: darkPrimary,
      scaffoldBackgroundColor: darkBg,
      cardColor: surfaceColor,
      colorScheme: base.colorScheme.copyWith(
        primary: darkPrimary,
        secondary: darkAccent,
        surface: surfaceColor,
        onSurface: darkTextPrimary,
        error: errorRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(color: darkTextPrimary, fontSize: 22, fontWeight: FontWeight.w600),
        centerTitle: false,
      ),
      textTheme: _buildTextTheme(base).apply(bodyColor: darkTextPrimary, displayColor: darkTextPrimary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkAccent,
          foregroundColor: accentGoldDark,
          elevation: 1,
          shadowColor: primaryTeal.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.7),
          textStyle: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))), // Corner radius 12px for cards
        color: surfaceColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      ),
    );
  }
}
