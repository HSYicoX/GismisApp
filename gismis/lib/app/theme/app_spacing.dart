import 'package:flutter/material.dart';

/// Gismis spacing system - magazine-like generous spacing
/// for a calm, balanced composition.
abstract final class AppSpacing {
  // Base spacing values
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Page-level spacing
  static const double pageHorizontal = 20;
  static const double pageVertical = 24;

  // Component spacing
  static const double cardPadding = 16;
  static const double sectionGap = 32;
  static const double listItemGap = 12;

  // Border radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  // Common EdgeInsets
  static const pagePadding = EdgeInsets.symmetric(
    horizontal: pageHorizontal,
    vertical: pageVertical,
  );

  static const cardMargin = EdgeInsets.all(cardPadding);

  static const listPadding = EdgeInsets.symmetric(
    horizontal: pageHorizontal,
    vertical: sm,
  );

  // Common SizedBox widgets for spacing
  static const verticalXs = SizedBox(height: xs);
  static const verticalSm = SizedBox(height: sm);
  static const verticalMd = SizedBox(height: md);
  static const verticalLg = SizedBox(height: lg);
  static const verticalXl = SizedBox(height: xl);
  static const verticalXxl = SizedBox(height: xxl);

  static const horizontalXs = SizedBox(width: xs);
  static const horizontalSm = SizedBox(width: sm);
  static const horizontalMd = SizedBox(width: md);
  static const horizontalLg = SizedBox(width: lg);
  static const horizontalXl = SizedBox(width: xl);
}
