import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta base — más oscura y profesional, manteniendo la identidad de marca
  static const Color background = Color(0xFF0A0E18);
  static const Color surface = Color(0xFF141A28);
  static const Color surfaceAlt = Color(0xFF1A2132);
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color secondary = Color(0xFFFF6B35);
  static const Color tertiary = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color gold = Color(0xFFF59E0B);
  static const Color white = Color(0xFFF8FAFC);
  static const Color grey = Color(0xFF98A2B3);
  static const Color darkGrey = Color(0xFF5C6675);
  static const Color border = Color(0xFF242C3D);

  static TextStyle get displayLarge => GoogleFonts.sora(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: white,
      );

  static TextStyle get displayMedium => GoogleFonts.sora(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: white,
      );

  static TextStyle get headlineLarge => GoogleFonts.sora(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: white,
      );

  static TextStyle get headlineMedium => GoogleFonts.sora(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: white,
      );

  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: white,
      );

  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: white,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: grey,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: grey,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: darkGrey,
      );

  static TextStyle get counterLarge => GoogleFonts.sora(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: primary,
      );

  static TextStyle get counterMedium => GoogleFonts.sora(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: primary,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: grey,
        letterSpacing: 1.2,
      );

  static ThemeData get darkTheme {
    final baseScheme = ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      error: error,
      surface: surface,
      surfaceContainerHighest: surfaceAlt,
      outline: border,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: baseScheme,
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: white,
        ),
        iconTheme: const IconThemeData(color: white),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: white,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: white,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: darkGrey),
        hintStyle: GoogleFonts.inter(fontSize: 13, color: darkGrey),
        prefixIconColor: primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceAlt,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: darkGrey,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    );
  }
}
