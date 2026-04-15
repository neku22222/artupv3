import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const cream        = Color(0xFFFDF8F0);
  static const warmWhite    = Color(0xFFFFFDF9);
  static const peach        = Color(0xFFE8845A);
  static const peachLight   = Color(0xFFF5C4A8);
  static const peachPale    = Color(0xFFFDF0E8);
  static const amber        = Color(0xFFD4A04A);
  static const brown        = Color(0xFF8B5E3C);
  static const muted        = Color(0xFF9A8878);
  static const border       = Color(0xFFEEDDD0);
  static const dark         = Color(0xFF2A1F18);
  static const cardBg       = Color(0xFFFFFFFF);
  static const onlineGreen  = Color(0xFF4CAF50);
  static const errorRed     = Color(0xFFE05050);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.peach, background: AppColors.cream),
    scaffoldBackgroundColor: AppColors.cream,
    textTheme: GoogleFonts.dmSansTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.warmWhite,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.playfairDisplay(
        fontSize: 22, fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic, color: AppColors.peach,
      ),
      iconTheme: const IconThemeData(color: AppColors.peach),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardBg,
      hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.peach, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    useMaterial3: true,
  );
}
