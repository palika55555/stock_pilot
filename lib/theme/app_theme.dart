import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds
  static const Color bgPrimary = Color(0xFF0A0C12);
  static const Color bgCard = Color(0xFF12151F);
  static const Color bgElevated = Color(0xFF1A1E2E);
  static const Color bgInput = Color(0xFF1E2235);

  // Accent
  static const Color accentGold = Color(0xFFF5A623);
  static const Color accentGoldSubtle = Color(0x1FF5A623); // ~12% opacity
  static const Color accentPurple = Color(0xFF9B59B6);
  static const Color accentPurpleSubtle = Color(0x1F9B59B6); // ~12% opacity

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color successSubtle = Color(0x1F22C55E);
  static const Color warning = Color(0xFFF97316);
  static const Color warningSubtle = Color(0x1FF97316);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSubtle = Color(0x1FEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoSubtle = Color(0x1F3B82F6);

  // Text
  static const Color textPrimary = Color(0xFFF1F3F9);
  static const Color textSecondary = Color(0xFF8B92A9);
  static const Color textMuted = Color(0xFF4B5568);

  // Borders
  static const Color borderSubtle = Color(0xFF1E2235);
  static const Color borderDefault = Color(0xFF252A3D);

  /// Štýl kariet ako na Home stránke – pre Container/decoration.
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8)),
        ],
      );

  /// Menší radius pre malé karty (napr. štatistiky).
  static BoxDecoration cardDecorationSmall([double radius = 12]) => BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderSubtle, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
        ],
      );
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentGold,
        secondary: AppColors.accentGold,
        surface: AppColors.bgCard,
        error: AppColors.danger,
        onPrimary: AppColors.bgPrimary,
        onSecondary: AppColors.bgPrimary,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(fontSize: 57, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        displayMedium: GoogleFonts.outfit(fontSize: 45, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        displaySmall: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        headlineLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        headlineMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        headlineSmall: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleLarge: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleMedium: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleSmall: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textPrimary),
        bodyMedium: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textPrimary),
        bodySmall: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary),
        labelLarge: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        labelMedium: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        labelSmall: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
        ),
        hintStyle: GoogleFonts.dmSans(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGold,
          foregroundColor: AppColors.bgPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgElevated,
        contentTextStyle: GoogleFonts.dmSans(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        alignment: Alignment.center,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.bgCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        dragHandleColor: AppColors.textMuted,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentGold,
        ),
      ),
    );
  }
}
