import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Gismis typography system - artistic serif fonts for titles,
/// clean sans-serif for body text.
abstract final class AppTypography {
  // Font families
  static const titleFontFamily = 'NotoSerifSC';
  static const bodyFontFamily = 'NotoSansSC';

  // Display styles (large titles)
  static const displayLarge = TextStyle(
    fontFamily: titleFontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const displayMedium = TextStyle(
    fontFamily: titleFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static const displaySmall = TextStyle(
    fontFamily: titleFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  // Headline styles
  static const headlineLarge = TextStyle(
    fontFamily: titleFontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const headlineMedium = TextStyle(
    fontFamily: titleFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const headlineSmall = TextStyle(
    fontFamily: titleFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  // Title styles
  static const titleLarge = TextStyle(
    fontFamily: titleFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const titleMedium = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.15,
    color: AppColors.textPrimary,
  );

  static const titleSmall = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  // Body styles
  static const bodyLarge = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.textPrimary,
  );

  static const bodyMedium = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const bodySmall = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  // Label styles
  static const labelLarge = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static const labelMedium = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
  );

  static const labelSmall = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
    color: AppColors.textTertiary,
  );
}
