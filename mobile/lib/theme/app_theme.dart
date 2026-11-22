import 'package:flutter/material.dart';

/// EnableWork+ visual tokens. The palette keeps the Philippine-flag-inspired
/// brand colors while letting Material derive accessible light/dark surfaces.
abstract final class AppColors {
  static const royalBlue = Color(0xff0038a8);
  static const crimson = Color(0xffce1126);
  static const sunYellow = Color(0xfffcd116);
  static const ink = Color(0xff14213d);
  static const mutedInk = Color(0xff526176);
  static const canvas = Color(0xfff7f9fc);
  static const success = Color(0xff16794b);
  static const warning = Color(0xff946200);
}

abstract final class AppSpacing {
  static const page = 20.0;
  static const section = 24.0;
  static const card = 18.0;
  static const compact = 12.0;
  static const control = 48.0;
}

abstract final class AppTypography {
  static const display = TextStyle(
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );
  static const eyebrow = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );
}

abstract final class AppTheme {
  static ThemeData forBrightness(
    Brightness brightness, {
    bool highContrast = false,
    bool reduceMotion = false,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.royalBlue,
          brightness: brightness,
          contrastLevel: highContrast ? 1 : 0,
        ).copyWith(
          secondary: AppColors.crimson,
          onSecondary: Colors.white,
          tertiary: AppColors.sunYellow,
          surface: dark ? const Color(0xff111827) : Colors.white,
          surfaceContainerLowest: dark ? const Color(0xff0b1220) : Colors.white,
          surfaceContainerLow: dark
              ? const Color(0xff172033)
              : AppColors.canvas,
          onSurface: dark ? const Color(0xfff8fafc) : AppColors.ink,
          onSurfaceVariant: dark ? const Color(0xffc7d0df) : AppColors.mutedInk,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLow,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: reduceMotion
          ? NoSplash.splashFactory
          : InkRipple.splashFactory,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.royalBlue, width: 2),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: dark ? 2 : 2,
        shadowColor: dark ? Colors.black54 : Colors.black12,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.card),
          side: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.control),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: AppColors.royalBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black26,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.control),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide.none,
          elevation: 1,
          shadowColor: Colors.black12,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.control),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            letterSpacing: 0,
            height: 1.2,
            fontWeight: highContrast ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        height: 78,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: AppTypography.display.copyWith(color: scheme.onSurface),
        headlineMedium: AppTypography.display.copyWith(color: scheme.onSurface),
        titleLarge: base.textTheme.titleLarge!.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        titleMedium: base.textTheme.titleMedium!.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        bodyLarge: base.textTheme.bodyLarge!.copyWith(
          height: 1.45,
          color: scheme.onSurface,
        ),
        bodyMedium: base.textTheme.bodyMedium!.copyWith(
          height: 1.4,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
