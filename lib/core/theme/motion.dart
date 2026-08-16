import 'package:flutter/animation.dart';

/// Motion tokens for `designs/sonic_sanctuary_2/DESIGN.md`.
///
/// DESIGN.md defines almost no motion values. The only literal data point
/// anywhere in the doc is the primary-button press scale (0.98x). No
/// durations or easing curves are specified at all — everything else below
/// is a standard Material-3-style derivation, approved as-is 2026-08-17.
/// No ThemeData slot exists for arbitrary durations/curves, so these are
/// used directly (e.g. `AnimatedContainer(duration: AppMotion.standard,
/// curve: AppMotion.standardEasing)`), the same way AppSpacing/AppRadius are.
class AppMotion {
  AppMotion._();

  // --- Literal from DESIGN.md ---

  /// Primary button "High-press feedback using scale (0.98x)".
  static const double pressScale = 0.98;

  // --- Derived, not in DESIGN.md ---

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration emphasized = Duration(milliseconds: 400);

  /// For the "slowly animating" atmospheric background gradients — DESIGN.md
  /// says "slowly" but gives no number.
  static const Duration atmosphericDrift = Duration(seconds: 12);

  static const Curve standardEasing = Curves.easeOutCubic;
  static const Curve emphasizedEasing = Curves.easeOutQuint;
}
