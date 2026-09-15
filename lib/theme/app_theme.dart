import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Official Zameel design system — Premium University Social Lifestyle Brand.
class AppTheme {
  static const Color primary = Color(0xFF3152E8);
  static const Color primaryDark = Color(0xFF4B23B7);
  static const Color primaryLight = Color(0xFFE9EDFF);
  static const Color secondary = Color(0xFF4B23B7);
  static const Color secondaryLight = Color(0xFFF0EBFF);
  static const Color tertiary = Color(0xFF27C7C7);
  static const Color accent = Color(0xFF27C7C7);
  static const Color accentSoft = Color(0xFFE7F9F9);
  static const Color background = Color(0xFFF7F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF0F2F8);
  static const Color textPrimary = Color(0xFF151725);
  static const Color textSecondary = Color(0xFF62677A);
  static const Color border = Color(0xFFE1E4EE);
  static const Color night = Color(0xFF151725);
  static const Color nightSurface = Color(0xFF1D2030);
  static const Color nightSurfaceAlt = Color(0xFF262A3D);

  static const LinearGradient signatureGradient = LinearGradient(
    colors: [primaryDark, primary], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const LinearGradient signatureGradientRtl = LinearGradient(
    colors: [primary, primaryDark], begin: Alignment.topRight, end: Alignment.bottomLeft);
  static const double cardRadius = 18;
  static const double controlRadius = 14;
  static const double logoSafeSpaceRatio = .22;
  static const double minimumLogoSize = 28;

  static const MaterialColor muted = MaterialColor(0xFF858A9E, <int, Color>{
    50: Color(0xFFF7F8FC), 100: Color(0xFFEEF0F6), 200: Color(0xFFDDE0EA),
    300: Color(0xFFC5C9D6), 400: Color(0xFFA4A9BA), 500: Color(0xFF858A9E),
    600: Color(0xFF696F84), 700: Color(0xFF53586B), 800: Color(0xFF3B4051),
    900: Color(0xFF252938),
  });
  static const Color overlaySoft = Color(0x143152E8);
  static const Color overlayMedium = Color(0x223152E8);
  static const Color overlayStrong = Color(0x334B23B7);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC3545);

  // Graduation book keeps a restrained editorial paper palette.
  static const Color bookPaper = Color(0xFFFCF4E6);
  static const Color bookPaperSoft = Color(0xFFF8F1E5);
  static const Color bookPaperAlt = Color(0xFFFFFEF7);
  static const Color bookPaperDeep = Color(0xFFF7EFDF);
  static const Color bookAccent = Color(0xFFDDE3FF);
  static const Color bookAccentLight = Color(0xFFC9D2FF);
  static const Color bookBorder = Color(0xFFE5D7BE);
  static const Color bookBorderSoft = Color(0xFFE9DEC9);
  static const Color bookText = Color(0xFF49506B);
  static const Color bookTextSoft = Color(0xFF6D7080);
  static const Color bookTextDeep = Color(0xFF33384F);
  static const Color bookEarth = Color(0xFFD8C8AE);
  static const Color bookOlive = Color(0xFF7A604A);
  static const Color bookShadow = Color(0x33000000);
  static const Color bookShadowSoft = Color(0x22000000);
  static const Color bookTealShadow = Color(0x183152E8);
  static const Color bookPhotoShadow = Color(0x45000000);
  static const Color bookGoldShadow = Color(0x66D8C79F);
  static const Color bookWhiteOverlay = Color(0x22FFFFFF);
  static const Color bookPaperOverlay = Color(0xBFFFFFFA);
  static const Color bookOliveOverlay = Color(0x557A604A);
  static const Color bookOliveOverlayStrong = Color(0x664C3A2B);
  static const Color bookTealShadowLight = Color(0x123152E8);
  static const Color glassFill = Color(0x26FFFFFF);
  static const Color glassBorder = Color(0x55FFFFFF);
  static const Color glassSoft = Color(0x14FFFFFF);
  static const Color glassMid = Color(0x33FFFFFF);

  static TextTheme _type(bool arabic, Brightness brightness) {
    // Zameel keeps primary reading text black throughout the product. Colored
    // surfaces that need inverse text still set white explicitly.
    const color = Colors.black;
    const secondaryColor = Colors.black87;
    final base = TextTheme(
      headlineLarge: TextStyle(color: color, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(color: color, fontWeight: FontWeight.w800),
      headlineSmall: TextStyle(color: color, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: color, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: color, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: color, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: color, height: 1.45),
      bodyMedium: TextStyle(color: secondaryColor, height: 1.45),
      bodySmall: TextStyle(color: secondaryColor, height: 1.35),
      labelLarge: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
    return arabic ? GoogleFonts.ibmPlexSansArabicTextTheme(base) : GoogleFonts.interTextTheme(base);
  }

  static ThemeData theme({required bool arabic, required Brightness brightness}) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? night : background;
    final card = dark ? nightSurface : surface;
    final alt = dark ? nightSurfaceAlt : surfaceAlt;
    const foreground = Colors.black;
    final outline = dark ? const Color(0xFF363B51) : border;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary, brightness: brightness, primary: primary,
      secondary: secondary, tertiary: tertiary, surface: card, error: error,
    ).copyWith(
      primaryContainer: dark ? const Color(0xFF273775) : primaryLight,
      secondaryContainer: dark ? const Color(0xFF352668) : secondaryLight,
      surfaceContainerHighest: alt, outline: outline,
    );
    final type = _type(arabic, brightness);
    return ThemeData(
      useMaterial3: true, brightness: brightness, colorScheme: scheme,
      scaffoldBackgroundColor: bg, textTheme: type,
      iconTheme: IconThemeData(color: foreground, size: 23),
      appBarTheme: AppBarTheme(
        backgroundColor: card, foregroundColor: foreground, elevation: 0,
        scrolledUnderElevation: 1, centerTitle: false, titleTextStyle: type.titleLarge,
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: card, elevation: 0, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius), side: BorderSide(color: outline)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: alt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: const BorderSide(color: primary, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: const BorderSide(color: error)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: primary, foregroundColor: Colors.white, elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: dark ? Colors.white : primary, minimumSize: const Size(double.infinity, 50),
        side: BorderSide(color: outline), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)))),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: primary, foregroundColor: Colors.white, elevation: 3),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: card, indicatorColor: dark ? const Color(0xFF273775) : primaryLight),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(backgroundColor: card, selectedItemColor: primary, unselectedItemColor: muted, elevation: 8),
      chipTheme: ChipThemeData(
        backgroundColor: alt, selectedColor: dark ? const Color(0xFF273775) : primaryLight,
        side: BorderSide(color: outline), labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: primary, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFF30354A) : night,
        contentTextStyle: const TextStyle(color: Colors.white), behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  static ThemeData get lightTheme => theme(arabic: false, brightness: Brightness.light);
  static ThemeData get darkTheme => theme(arabic: false, brightness: Brightness.dark);
}
