import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Zameel visual system.
///
/// The palette keeps Zameel teal as the brand anchor, supported by a calm
/// deep-teal text color, soft mint surfaces, and restrained semantic accents.
/// It is intentionally centralized so screens do not drift into unrelated colors.
class AppTheme {
  // Brand colors — anchored to the updated Zameel identity.
  static const Color primary = Color(0xFF44A2A6);
  static const Color primaryDark = Color(0xFF172326);
  static const Color primaryLight = Color(0xFFDFF3F3);

  // Supporting colors are deliberately close to the main teal family.
  static const Color secondary = Color(0xFF2F7F82);
  static const Color secondaryLight = Color(0xFFE8F5F3);
  static const Color tertiary = Color(0xFF5BB9AE);
  static const Color accent = Color(0xFF74C9C2);
  static const Color accentSoft = Color(0xFFE7F6F4);
  static const MaterialColor muted = MaterialColor(
    0xFF8A9B9D,
    <int, Color>{
      50: Color(0xFFF5F8F8),
      100: Color(0xFFE8EEEE),
      200: Color(0xFFD0DADC),
      300: Color(0xFFB8C5C7),
      400: Color(0xFFA1B0B2),
      500: Color(0xFF8A9B9D),
      600: Color(0xFF6F8285),
      700: Color(0xFF5A6B6E),
      800: Color(0xFF445356),
      900: Color(0xFF303E41),
    },
  );
  static const Color overlaySoft = Color(0x145A7B7D);
  static const Color overlayMedium = Color(0x225A7B7D);
  static const Color overlayStrong = Color(0x335A7B7D);

  // Graduation book: a warm paper system that remains part of Zameel,
  // but uses restrained teal/earth tones rather than introducing random UI colors.
  static const Color bookPaper = Color(0xFFFCF4E6);
  static const Color bookPaperSoft = Color(0xFFF8F1E5);
  static const Color bookPaperAlt = Color(0xFFFFFEF7);
  static const Color bookPaperDeep = Color(0xFFF7EFDF);
  static const Color bookAccent = Color(0xFFCBE9E4);
  static const Color bookAccentLight = Color(0xFFBFE1E2);
  static const Color bookBorder = Color(0xFFE5D7BE);
  static const Color bookBorderSoft = Color(0xFFE9DEC9);
  static const Color bookText = Color(0xFF5F7C78);
  static const Color bookTextSoft = Color(0xFF6D766F);
  static const Color bookTextDeep = Color(0xFF58716C);
  static const Color bookEarth = Color(0xFFD8C8AE);
  static const Color bookOlive = Color(0xFF7A604A);
  static const Color bookShadow = Color(0x33000000);
  static const Color bookShadowSoft = Color(0x22000000);
  static const Color bookTealShadow = Color(0x180B6F68);
  static const Color bookPhotoShadow = Color(0x45000000);
  static const Color bookGoldShadow = Color(0x66D8C79F);
  static const Color bookWhiteOverlay = Color(0x22FFFFFF);
  static const Color bookPaperOverlay = Color(0xBFFFFFFA);
  static const Color bookOliveOverlay = Color(0x557A604A);
  static const Color bookOliveOverlayStrong = Color(0x664C3A2B);
  static const Color bookTealShadowLight = Color(0x120B6F68);

  // Glass/overlay tokens used by the auth and onboarding surfaces.
  static const Color glassFill = Color(0x33FFFFFF);
  static const Color glassBorder = Color(0x66FFFFFF);
  static const Color glassSoft = Color(0x1AFFFFFF);
  static const Color glassMid = Color(0x44FFFFFF);

  // Neutral foundation — softer than pure grey while keeping cards clean.
  static const Color background = Color(0xFFF7FAF9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF1F5F5);
  static const Color textPrimary = Color(0xFF172326);
  static const Color textSecondary = Color(0xFF68777A);
  static const Color border = Color(0xFFE2E8F0);

  // Semantic states.
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC3545);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryLight,
      onPrimaryContainer: primaryDark,
      secondary: secondary,
      onSecondary: Colors.white,
      secondaryContainer: secondaryLight,
      onSecondaryContainer: primaryDark,
      tertiary: tertiary,
      onTertiary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceAlt,
      outline: border,
      error: error,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryDark,
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceAlt,
      selectedColor: primaryLight,
      side: const BorderSide(color: border),
      labelStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: primaryDark, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(
      color: border,
      thickness: 1,
      space: 1,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
      headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      bodySmall: TextStyle(color: textSecondary),
      labelLarge: TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}
