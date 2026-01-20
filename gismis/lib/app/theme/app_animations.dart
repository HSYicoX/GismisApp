import 'package:flutter/material.dart';

/// Gismis animation specifications - gentle, fluid animations
/// for a calm, relaxed user experience.
abstract final class AppAnimations {
  // Durations
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
  static const pageTransition = Duration(milliseconds: 400);
  static const shimmer = Duration(milliseconds: 1500);

  // Curves (gentle easing)
  static const defaultCurve = Curves.easeOutCubic;
  static const enterCurve = Curves.easeOutQuart;
  static const exitCurve = Curves.easeInCubic;
  static const bounceCurve = Curves.easeOutBack;

  // Field blur animation for AI streaming
  static const double blurAmount = 8;
  static const double blurOpacity = 0.5;
  static const clearDuration = Duration(milliseconds: 400);

  // Skeleton shimmer
  static const shimmerDuration = Duration(milliseconds: 1500);

  // Hero animation
  static const heroDuration = Duration(milliseconds: 350);
  static const heroCurve = Curves.easeInOutCubic;

  // List item stagger
  static const staggerDelay = Duration(milliseconds: 50);
  static const staggerDuration = Duration(milliseconds: 300);
}
