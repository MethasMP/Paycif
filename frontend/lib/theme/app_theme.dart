import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - New Design System (Teal & Gold)
  static const Color primaryTeal = Color(0xFF0F6E56); // primary-600
  static const Color primaryTealDark = Color(0xFF085041); // primary-800
  static const Color primaryTealLight = Color(0xFFE1F5EE); // primary-100
  
  static const Color accentGold = Color(0xFFEF9F27); // accent-500
  static const Color accentGoldDisabled = Color(0xFFFAC775); // accent-300
  static const Color accentGoldDark = Color(0xFF412402); // accent-900

  static const Color backgroundWhite = Color(0xFFFFFFFF); // bg-primary
  static const Color backgroundGrey = Color(0xFFF7F7F5); // bg-secondary
  static const Color borderGrey = Color(0xFFE5E5E3); // border

  static const Color textPrimary = Color(0xFF111111); // text-primary
  static const Color textSecondary = Color(0xFF666664); // text-secondary
  static const Color textPlaceholder = Color(0xFFAAAAAA); // text-tertiary

  // Semantic
  static const Color errorRed = Color(0xFFD92D20); // error
  static const Color successGreen = Color(0xFF0F6E56); // success (primary-600)
  static const Color warningAmber = Color(0xFFF79009); // warning
  static const Color infoBlue = Color(0xFF1570EF); // info

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
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 40 / 32,
      ).copyWith(fontFamilyFallback: thaiFallback), // Display: 32/40, 600
      headlineLarge: GoogleFonts.ibmPlexSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
      ).copyWith(fontFamilyFallback: thaiFallback), // H1: 24/32, 600
      headlineMedium: GoogleFonts.ibmPlexSans(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 28 / 20,
      ).copyWith(fontFamilyFallback: thaiFallback), // H2: 20/28, 500
      headlineSmall: GoogleFonts.ibmPlexSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
      ).copyWith(fontFamilyFallback: thaiFallback), // headlineSmall: 20/28, 600
      titleLarge: GoogleFonts.ibmPlexSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
      ).copyWith(fontFamilyFallback: thaiFallback), // titleLarge: 20/28, 600
      bodyLarge: GoogleFonts.ibmPlexSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      ).copyWith(fontFamilyFallback: thaiFallback), // Body: 16/24, 400
      bodyMedium: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 22 / 14,
      ).copyWith(fontFamilyFallback: thaiFallback), // bodyMedium: 14/22, 400
      bodySmall: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 20 / 13,
      ).copyWith(fontFamilyFallback: thaiFallback), // Caption: 13/20, 400
      labelLarge: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
      ).copyWith(fontFamilyFallback: thaiFallback), // labelLarge: 14/20, 500
      labelSmall: GoogleFonts.ibmPlexSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 16 / 11,
      ).copyWith(fontFamilyFallback: thaiFallback), // labelSmall: 11/16, 500
      displayMedium: GoogleFonts.ibmPlexSans(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        height: 36 / 28,
        fontFeatures: const [FontFeature.tabularFigures()],
      ).copyWith(fontFamilyFallback: thaiFallback), // Numeric: 28/36, 500
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      primaryColor: primaryTeal,
      scaffoldBackgroundColor: backgroundWhite,
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
