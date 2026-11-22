import 'package:flutter/material.dart';

abstract final class AdminColors {
  static const royalBlue = Color(0xff0038a8);
  static const crimson = Color(0xffce1126);
  static const sunYellow = Color(0xfffcd116);
  static const navy = Color(0xff14213d);
  static const muted = Color(0xff5f6c80);
  static const canvas = Color(0xfff5f7fb);
  static const border = Color(0xffe3e8f0);
  static const success = Color(0xff16794b);
  static const warning = Color(0xff946200);
}

abstract final class AdminSpacing {
  static const page = 28.0;
  static const card = 20.0;
  static const control = 48.0;
}

abstract final class AdminTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AdminColors.royalBlue,
          brightness: Brightness.light,
        ).copyWith(
          secondary: AdminColors.crimson,
          tertiary: AdminColors.sunYellow,
          surface: Colors.white,
          surfaceContainerLow: AdminColors.canvas,
          onSurface: AdminColors.navy,
          onSurfaceVariant: AdminColors.muted,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AdminColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AdminColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.royalBlue, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AdminSpacing.control),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AdminColors.royalBlue,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AdminSpacing.control),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: IconThemeData(color: AdminColors.royalBlue),
        selectedLabelTextStyle: TextStyle(
          color: AdminColors.royalBlue,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: AdminColors.muted),
      ),
    );
  }
}
