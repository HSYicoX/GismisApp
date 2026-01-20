import 'package:flutter/material.dart';

/// Gismis color palette - soft, natural colors with warm off-white,
/// beige, light gray, and muted pastel accents for a calm, artistic aesthetic.
abstract final class AppColors {
  // Background colors
  static const background = Color(0xFFFAF8F5); // Warm off-white
  static const surface = Color(0xFFFFFEFC); // Pure cream
  static const surfaceVariant = Color(0xFFF5F2ED); // Light beige

  // Text colors
  static const textPrimary = Color(0xFF2D2A26); // Warm dark brown
  static const textSecondary = Color(0xFF6B6560); // Muted brown
  static const textTertiary = Color(0xFF9E9891); // Light brown

  // Accent colors (muted pastels)
  static const accentOlive = Color(0xFF8B9A6D); // Muted olive green
  static const accentTerracotta = Color(0xFFBE8A6E); // Soft terracotta
  static const accentSky = Color(0xFF8BA4B4); // Muted sky blue
  static const accentLavender = Color(0xFFA89BB4); // Soft lavender

  // Functional colors
  static const error = Color(0xFFB85C5C); // Muted red
  static const success = Color(0xFF7A9B6D); // Muted green
  static const divider = Color(0xFFE8E4DF); // Very light gray
  static const skeleton = Color(0xFFEBE7E2); // Skeleton placeholder
  static const shimmerHighlight = Color(0xFFF5F2ED); // Shimmer highlight

  // Overlay colors
  static const scrim = Color(0x662D2A26); // Semi-transparent dark
  static const overlay = Color(0x0D2D2A26); // Very light overlay
}
