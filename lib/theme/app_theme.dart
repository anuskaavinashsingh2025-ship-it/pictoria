import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Text styles used across the app.
///
/// Headlines use the bundled serif (DM Serif Display) for a classy, editorial
/// feel; everything else uses the platform's default sans-serif for clarity.
abstract final class AppText {
  static const serifFamily = 'DMSerifDisplay';

  static const display = TextStyle(
    fontFamily: serifFamily,
    fontSize: 42,
    height: 1.04,
    letterSpacing: -0.5,
    color: AppColors.ink,
  );

  static const wordmark = TextStyle(
    fontFamily: serifFamily,
    fontSize: 30,
    height: 1,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 1.45,
    color: AppColors.inkMuted,
  );

  static const sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.inkMuted,
  );

  static const label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const navLabel = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
}

/// The app-wide Material theme, built from the design tokens.
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.ivory,
    onSurface: AppColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.cream,
    splashFactory: InkSparkle.splashFactory,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
  );
}
