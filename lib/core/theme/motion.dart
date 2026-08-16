import 'package:flutter/animation.dart';

/// Motion tokens for `designs/sonic_sanctuary_2/DESIGN.md`.
///
/// PROPOSED — DESIGN.md defines almost no motion values. The only literal
/// data point anywhere in the doc is the primary-button press scale (0.98x).
/// No durations or easing curves are specified at all. Everything else below
/// is a standard Material-3-style proposal and needs your sign-off before
/// `theme_data.dart` or any widget relies on it.
class AppMotion {
  AppMotion._();

  // --- Literal from DESIGN.md ---

  /// Primary button "High-press feedback using scale (0.98x)".
  static const double pressScale = 0.98;

  // --- PROPOSED, not in DESIGN.md — confirm before use ---

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration emphasized = Duration(milliseconds: 400);

  /// For the "slowly animating" atmospheric background gradients — DESIGN.md
  /// says "slowly" but gives no number.
  static const Duration atmosphericDrift = Duration(seconds: 12);

  static const Curve standardEasing = Curves.easeOutCubic;
  static const Curve emphasizedEasing = Curves.easeOutQuint;
}
