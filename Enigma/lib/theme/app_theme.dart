import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand & Palette Colors (Modern Vibrant & Harmonious)
  static const Color primary = Color(0xFFDA6556);       // Terracotta / Warm Coral
  static const Color primaryLight = Color(0xFFE88A7D);  // Soft Coral
  static const Color primaryDark = Color(0xFFB8483B);   // Deep Terracotta
  static const Color secondary = Color(0xFF8ACFF8);     // Sky Blue / Pastel Blue
  static const Color accentMint = Color(0xFFB8CFB3);    // Sage Green / Soft Herbal
  static const Color accentAmber = Color(0xFFDB9558);   // Warm Amber / Apricot
  static const Color accentCoral = Color(0xFFDA6556);   // Terracotta / Coral
  static const Color accentPurple = Color(0xFF9D84B7);  // Soft Muted Lavender
  static const Color accentSky = Color(0xFF8ACFF8);     // Pastel Sky Blue

  // ── Dark Mode Backgrounds & Surfaces ─────────────────────────────────────
  static const Color bgDark = Color(0xFF090D16);         // Deep Midnight Obsidian
  static const Color bgSurface = Color(0xFF111726);      // Premium Card Surface
  static const Color bgSurfaceLight = Color(0xFF1C2438); // Elevated Surface / Chips
  static const Color cardBorder = Color(0x1AFFFFFF);     // 10% white border
  static const Color cardBorderStrong = Color(0x33FFFFFF);// 20% white border for active

  // ── Dark Mode Text Colors ──────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // ── Light Mode Backgrounds & Surfaces ─────────────────────────────────────
  static const Color bgLight = Color(0xFFF5F7FA);          // Soft cool gray background
  static const Color bgLightSurface = Color(0xFFFFFFFF);   // White card surface
  static const Color bgLightSurfaceAlt = Color(0xFFEBEFF5);// Secondary gray surface
  static const Color cardBorderLight = Color(0x2264748B);  // Soft slate border
  static const Color cardBorderLightStrong = Color(0x4464748B);

  // ── Light Mode Text Colors ─────────────────────────────────────────────────
  static const Color textPrimaryLight = Color(0xFF1E293B); // Deep slate / High Contrast
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF64748B);

  // Pillar Specific Colors
  static const Color mentalColor = Color(0xFF8ACFF8);    // Sky Blue (#8ACFF8)
  static const Color sleepColor = Color(0xFF75BEE9);     // Soft Cyan/Sky
  static const Color physicalColor = Color(0xFFB8CFB3);  // Sage Green (#B8CFB3)
  static const Color socialColor = Color(0xFFDA6556);    // Coral Red (#DA6556)
  static const Color careerColor = Color(0xFFDB9558);    // Warm Amber (#DB9558)

  // Cached ThemeData instances to avoid expensive font & theme re-evaluations during switches
  static final ThemeData darkTheme = _buildDarkTheme();
  static final ThemeData lightTheme = _buildLightTheme();

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: bgSurface,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -1.0),
        displayMedium: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        displaySmall: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w700),
        headlineSmall: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 15, height: 1.5),
        bodyMedium: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 13, height: 1.45),
        bodySmall: GoogleFonts.plusJakartaSans(color: textMuted, fontSize: 12, height: 1.4),
        labelLarge: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
        labelMedium: GoogleFonts.plusJakartaSans(color: textSecondary, fontWeight: FontWeight.w500, fontSize: 12),
        labelSmall: GoogleFonts.plusJakartaSans(color: textMuted, fontWeight: FontWeight.w500, fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: cardBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ── Light Theme ─────────────────────────────────────────────────────────────
  static ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: bgLightSurface,
        onSurface: textPrimaryLight,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontWeight: FontWeight.w800, letterSpacing: -1.0),
        displayMedium: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        displaySmall: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontWeight: FontWeight.w700),
        headlineSmall: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontSize: 15, height: 1.5),
        bodyMedium: GoogleFonts.plusJakartaSans(color: textSecondaryLight, fontSize: 13, height: 1.45),
        bodySmall: GoogleFonts.plusJakartaSans(color: textMutedLight, fontSize: 12, height: 1.4),
        labelLarge: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontWeight: FontWeight.w600, fontSize: 13),
        labelMedium: GoogleFonts.plusJakartaSans(color: textSecondaryLight, fontWeight: FontWeight.w500, fontSize: 12),
        labelSmall: GoogleFonts.plusJakartaSans(color: textMutedLight, fontWeight: FontWeight.w500, fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: bgLightSurface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardBorderLight, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimaryLight,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: textPrimaryLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryLight,
          side: const BorderSide(color: cardBorderLight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ── Context-aware color helpers ───────────────────────────────────────────

  /// Returns the appropriate card background for the current theme brightness.
  static Color surfaceColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? bgSurface : bgLightSurface;
  }

  static Color surfaceAltColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? bgSurfaceLight : bgLightSurfaceAlt;
  }

  static Color borderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? cardBorder : cardBorderLight;
  }

  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color onSurfaceSecondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? textSecondary : textSecondaryLight;
  }

  static Color onSurfaceMuted(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? textMuted : textMutedLight;
  }

  // ── Context-aware decoration helpers ─────────────────────────────────────

  static BoxDecoration cardDecorationFor(
    BuildContext context, {
    double borderRadius = 20.0,
    Color? customColor,
    List<BoxShadow>? customShadow,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = customColor ?? (isDark ? bgSurface : bgLightSurface);
    final border = isDark ? cardBorder : cardBorderLight;
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border, width: 1.2),
      boxShadow: customShadow ??
          [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.30)
                  : const Color(0xFF64748B).withValues(alpha: 0.08),
              blurRadius: isDark ? 20 : 16,
              offset: const Offset(0, 8),
              spreadRadius: -3,
            ),
          ],
    );
  }

  /// iOS Liquid Glass decoration with specular highlights and fluid gradient
  static BoxDecoration liquidGlassDecoration(
    BuildContext context, {
    double borderRadius = 22.0,
    Color? tint,
    double opacity = 0.60,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = tint ??
        (isDark
            ? const Color(0xFF161E31).withValues(alpha: opacity)
            : bgLightSurface.withValues(alpha: opacity + 0.15));

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                (tint ?? const Color(0xFF283652)).withValues(alpha: opacity + 0.1),
                base,
                (tint ?? const Color(0xFF0F1626)).withValues(alpha: opacity * 0.8),
              ]
            : [
                Colors.white.withValues(alpha: 0.90),
                base,
                bgLightSurfaceAlt.withValues(alpha: opacity),
              ],
        stops: const [0.0, 0.45, 1.0],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.75),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : const Color(0xFF64748B).withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ],
    );
  }

  static BoxDecoration glassDecorationFor(
    BuildContext context, {
    double borderRadius = 20.0,
    double opacity = 0.55,
  }) {
    return liquidGlassDecoration(
      context,
      borderRadius: borderRadius,
      opacity: opacity,
    );
  }

  // Modern Card Decoration Helper
  static BoxDecoration cardDecoration({
    double borderRadius = 20.0,
    Color color = bgSurface,
    Color? borderColor,
    List<BoxShadow>? customShadow,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? cardBorder,
        width: 1.2,
      ),
      boxShadow: customShadow ?? [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 18,
          offset: const Offset(0, 8),
          spreadRadius: -3,
        ),
      ],
    );
  }

  // Modern Gradient Card Decoration Helper
  static BoxDecoration gradientCardDecoration({
    double borderRadius = 20.0,
    required List<Color> colors,
    Color? borderColor,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.25),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: colors.first.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ],
    );
  }

  // Glass / Frosted Decoration Helper
  static BoxDecoration glassDecoration({
    double borderRadius = 20.0,
    double opacity = 0.55,
    Color? borderColor,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: opacity * 0.9),
          Colors.white.withValues(alpha: opacity * 0.4),
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.35),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
      ],
    );
  }
}
