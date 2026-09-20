import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds — Crimson Velvet
  static const Color bgDeep      = Color(0xFF1A0A0D);
  static const Color bgMid       = Color(0xFF2C0F12);
  static const Color bgCard      = Color(0xFF3D1519);
  static const Color bgCardAlt   = Color(0xFF4A1920);

  // Primary Crimson Accent
  static const Color primary     = Color(0xFF6B1E23);
  static const Color primaryGlow = Color(0xFF9B3A41);
  static const Color accent      = Color(0xFFC0464F);
  static const Color accentLight = Color(0xFFE07079);

  // Status
  static const Color success     = Color(0xFF22C55E);
  static const Color successGlow = Color(0xFF4ADE80);
  static const Color warning     = Color(0xFFF59E0B);
  static const Color warningGlow = Color(0xFFFBBF24);
  static const Color danger      = Color(0xFFEF4444);
  static const Color dangerGlow  = Color(0xFFFCA5A5);

  // Text
  static const Color textPrimary   = Color(0xFFFDF2F3);
  static const Color textSecondary = Color(0xFFD4A0A5);
  static const Color textMuted     = Color(0xFF8B5A60);

  // Borders
  static const Color border      = Color(0xFF5A1E24);
  static const Color borderFocus = Color(0xFF9B3A41);

  // Gradients
  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF1A0A0D), Color(0xFF3D1519), Color(0xFF1A0A0D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6B1E23), Color(0xFF9B3A41)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF9B3A41), Color(0xFFC0464F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF3D1519), Color(0xFF4A1920)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dashGradient = LinearGradient(
    colors: [Color(0xFF1A0A0D), Color(0xFF2C0F12), Color(0xFF1F0C0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient scoreGradient = LinearGradient(
    colors: [Color(0xFF6B1E23), Color(0xFFC0464F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDeep,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.bgCard,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgCardAlt,
        selectedColor: AppColors.primary,
        labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
        secondaryLabelStyle: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: AppColors.border),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.accent,
        labelStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 14),
      ),
    );
  }

  static InputDecoration fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.accentLight, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.bgCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderFocus, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      errorStyle: const TextStyle(color: AppColors.dangerGlow, fontSize: 12),
    );
  }
}
