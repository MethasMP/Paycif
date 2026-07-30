import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Design System v2 Color Tokens ───

  // Light Mode Surface & Border
  static const Color lightSurfaceBase = Color(0xFFF8F9FC); // Ice-White consensus
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceSunken = Color(0xFFF1F3F9);
  static const Color lightBorderHairline = Color(0xFFD0D5E0);

  // Light Mode Text (Grayscale only)
  static const Color lightTextPrimary = Color(0xFF0A0E1A); // Align text with dark slate tone
  static const Color lightTextSecondary = Color(0xFF344054);
  static const Color lightTextTertiary = Color(0xFF475467);
  static const Color lightTextDisabled = Color(0xFF98A2B3);
  static const Color lightTextOnDark = Color(0xFFF8F9FC);

  // Dark Mode Surface & Border
  static const Color darkSurfaceBase = Color(0xFF0A0E1A); // Deep Navy-Slate consensus
  static const Color darkSurfaceCard = Color(0xFF121829);
  static const Color darkSurfaceSunken = Color(0xFF1A2138);
  static const Color darkBorderHairline = Color(0xFF333D5A);

  // Dark Mode Text (Grayscale only)
  static const Color darkTextPrimary = Color(0xFFF8F9FC);
  static const Color darkTextSecondary = Color(0xFFA6ACBE);
  static const Color darkTextTertiary = Color(0xFF949BAE);
  static const Color darkTextDisabled = Color(0xFF3F465B);
  static const Color darkTextOnDark = Color(0xFF0A0E1A);

  // Touch Target Constants & Helpers
  static const double minTouchTargetSize = 48.0;

  // Haptic Feedback Helpers
  static void triggerSelectionHaptic() {
    HapticFeedback.selectionClick();
  }

  static void triggerActionHaptic() {
    HapticFeedback.lightImpact();
  }

  static void triggerConfirmHaptic() {
    HapticFeedback.mediumImpact();
  }

  // Action Buttons — Grayscale Action Ink carries CTAs/focus states; everything else stays grayscale
  static const Color lightActionPrimary = Color(0xFF0A0E1A);
  static const Color lightActionPrimaryPress = Color(0xFF1E2538);
  static const Color darkActionPrimary = Color(0xFFF8F9FC);
  static const Color darkActionPrimaryPress = Color(0xFFE2E4EB);

  // Brand Signal (Success / Confirm Only)
  static const Color signalGreen = Color(0xFF10B981); // Emerald Green consensus
  static const Color signalGreenSubtleLight = Color(0xFFECFDF5);
  static const Color signalGreenSubtleDark = Color(0xFF064E3B);

  // Semantic States (Warning, Error, Info)
  static const Color stateError = Color(0xFFFF5A5F); // Cyber-Coral consensus
  static const Color stateErrorSubtleLight = Color(0xFFFFF1F2);
  static const Color stateErrorSubtleDark = Color(0xFF4C0519);

  static const Color stateWarning = Color(0xFFC9963A); // Gold survives only as warning
  static const Color stateWarningSubtleLight = Color(0xFFFBF3E7);
  static const Color stateWarningSubtleDark = Color(0xFF3F3218);

  static const Color stateInfo = Color(0xFF3B82C4);
  static const Color stateInfoSubtleLight = Color(0xFFEAF3FA);
  static const Color stateInfoSubtleDark = Color(0xFF19324C);

  // Fallbacks kept for backwards compatibility with call-sites
  static const Color primaryTeal = Color(0xFF00A896); // Flat Teal-Cyan consensus
  static const Color primaryTealDark = Color(0xFF008B7B);
  static const Color primaryTealLight = Color(0xFFE0F2F1);
  static const Color primaryTealDeep = lightActionPrimary;
  static const Color accentGold = stateWarning; // restored as a real gold accent, not an alias to teal
  static const Color accentGoldDisabled = lightTextDisabled;
  static const Color accentGoldDark = lightTextPrimary; // dark ink for legible text on the gold surface
  static const Color successGreen = signalGreen;
  static const Color errorRed = stateError;
  static const Color errorRedText = stateError;

  static const Color borderGrey = lightBorderHairline;
  static const Color backgroundGrey = lightSurfaceSunken;
  static const Color warningAmber = stateWarning;
  static const Color infoBlue = stateInfo;

  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color textPlaceholder = lightTextTertiary;
  static const Color successGreenText = Color(0xFF15803D); // v1 value for backward compatibility
  static const Color warningAmberText = Color(0xFFB45309); // v1 value for backward compatibility
  static const Color backgroundWhite = lightSurfaceCard;

  static Color textPrimaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  static Color primaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkActionPrimary : lightActionPrimary;

  // --type-amount — reserved for money figures only (rate ticker, payment
  // confirmation, transaction hero amounts): one weight heavier and tighter-tracked
  // than --type-display, so the number itself reads as the most confident mark
  // on the screen. Not for list-row amounts or any other numeral.
  static TextStyle amountTextStyle(BuildContext context, {Color? color}) {
    final base = Theme.of(context).textTheme.displayLarge;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 40,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      height: 1.05,
      color: color ?? base?.color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  // ─── Spacing and Radius Tokens ───
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 24.0;
  static const double space6 = 32.0;
  static const double space8 = 48.0;

  static const double radiusSm = 10.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 20.0;

  // ─── Typography & TextTheme ───

  static TextTheme _buildTextTheme(ThemeData base, Color textCol) {
    final String? thaiFontFamily = GoogleFonts.notoSansThai().fontFamily;
    final thaiFallback = thaiFontFamily != null ? [thaiFontFamily] : <String>[];

    // Primary font is Inter, falls back to Noto Sans Thai for Thai script.
    // Noto Sans Thai is metric-matched to Noto Sans (Latin) by the same foundry,
    // which sits closer to Inter's x-height/aperture than IBM Plex Sans Thai does —
    // less baseline/x-height seam where Thai merchant names sit next to Inter amounts.
    final baseStyle = GoogleFonts.inter().copyWith(
      color: textCol,
      fontFamilyFallback: thaiFallback,
    );

    return GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: baseStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ), // --type-display (amount confirmation)
      
      headlineLarge: baseStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ), // --type-h1 (screen titles)

      headlineMedium: baseStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ), // --type-h2 (section headers)

      bodyLarge: baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ), // --type-body-lg (primary body / button labels)

      bodyMedium: baseStyle.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ), // --type-body (standard body text)

      bodySmall: baseStyle.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ), // --type-body-sm (secondary / supporting)

      labelLarge: baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ), // --type-caption (timestamps, metadata)

      labelSmall: baseStyle.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.44, // +0.04em for uppercase eyebrows
      ), // --type-label (eyebrows, tab labels)
    );
  }

  // ─── Light Theme Configuration ───
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      primaryColor: lightActionPrimary,
      scaffoldBackgroundColor: lightSurfaceBase,
      cardColor: lightSurfaceCard,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lightActionPrimary,
        primary: lightActionPrimary,
        secondary: lightActionPrimary,
        surface: lightSurfaceCard,
        error: stateError,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        centerTitle: false,
      ),
      textTheme: _buildTextTheme(base, lightTextPrimary).apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightActionPrimary,
          foregroundColor: lightTextOnDark,
          elevation: 0, // Flat-at-rest rule: no shadow on static buttons
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg), // --radius-lg
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: space4,
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          tapTargetSize: MaterialTapTargetSize.padded,
          side: const BorderSide(color: lightBorderHairline, width: 1.0), // Hairline border
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: space4,
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightActionPrimary,
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 2.0,
        shadowColor: Color(0x1F0A0E1A),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFFD0D5E0), width: 1.0),
          borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
        ),
        color: lightSurfaceCard,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space4,
          vertical: space3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightBorderHairline, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightBorderHairline, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightActionPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: stateError, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: stateError, width: 2.0),
        ),
        errorStyle: const TextStyle(color: stateError),
        hintStyle: const TextStyle(color: lightTextTertiary),
      ),
      dialogTheme: const DialogThemeData(
        elevation: 0,
        backgroundColor: lightSurfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        backgroundColor: lightSurfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightActionPrimary,
        contentTextStyle: const TextStyle(
          color: lightTextOnDark,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        insetPadding: const EdgeInsets.all(space4),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1.0,
        color: lightBorderHairline,
        space: 1.0,
      ),
    );
  }

  // ─── Dark Theme Configuration ───
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      primaryColor: darkActionPrimary,
      scaffoldBackgroundColor: darkSurfaceBase,
      cardColor: darkSurfaceCard,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkActionPrimary,
        primary: darkActionPrimary,
        secondary: darkActionPrimary,
        surface: darkSurfaceCard,
        error: stateError,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        centerTitle: false,
      ),
      textTheme: _buildTextTheme(base, darkTextPrimary).apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkActionPrimary,
          foregroundColor: darkTextOnDark,
          elevation: 0,
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: space4,
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          tapTargetSize: MaterialTapTargetSize.padded,
          side: const BorderSide(color: darkBorderHairline, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: space4,
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkActionPrimary,
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 3.0,
        shadowColor: Color(0x3F000000),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFF333D5A), width: 1.0),
          borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
        ),
        color: darkSurfaceCard,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space4,
          vertical: space3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkBorderHairline, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkBorderHairline, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkActionPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: stateError, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: stateError, width: 2.0),
        ),
        errorStyle: const TextStyle(color: stateError),
        hintStyle: const TextStyle(color: darkTextTertiary),
      ),
      dialogTheme: const DialogThemeData(
        elevation: 0,
        backgroundColor: darkSurfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        backgroundColor: darkSurfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkActionPrimary,
        contentTextStyle: const TextStyle(
          color: darkTextOnDark,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        insetPadding: const EdgeInsets.all(space4),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1.0,
        color: darkBorderHairline,
        space: 1.0,
      ),
    );
  }

  /// Returns `true` if backdrop blurs and heavy graphics filters should be enabled.
  /// Disables blurs if system-level 'Reduce Motion' or 'Disable Animations' is active.
  static bool shouldEnableBlur(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.accessibleNavigation) return false;
    if (mediaQuery.disableAnimations) return false;
    return true;
  }
}

