import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds
  static const Color bgDeep      = Color(0xFF0A0E1A);
  static const Color bgMid       = Color(0xFF111827);
  static const Color bgCard      = Color(0xFF1A2035);
  static const Color bgCardAlt   = Color(0xFF1E2840);

  // Accents
  static const Color primary     = Color(0xFF7C3AED);
  static const Color primaryGlow = Color(0xFFA78BFA);
  static const Color secondary   = Color(0xFF06B6D4);
  static const Color secondaryGlow = Color(0xFF67E8F9);

  // Status
  static const Color success     = Color(0xFF10B981);
  static const Color warning     = Color(0xFFF59E0B);
  static const Color danger      = Color(0xFFF43F5E);
  static const Color dangerGlow  = Color(0xFFFB7185);

  // Text
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF475569);

  // Gradients
  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF0A0E1A), Color(0xFF130D2E), Color(0xFF0A0E1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A2035), Color(0xFF1E2840)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dashGradient = LinearGradient(
    colors: [Color(0xFF0A0E1A), Color(0xFF111827), Color(0xFF0F1729)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
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
        secondary: AppColors.secondary,
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  static InputDecoration fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.primaryGlow, size: 20),
      filled: true,
      fillColor: AppColors.bgCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF2D3748), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.primaryGlow, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      errorStyle: const TextStyle(color: AppColors.dangerGlow, fontSize: 12),
    );
  }
}
