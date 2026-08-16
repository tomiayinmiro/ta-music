import 'package:flutter/widgets.dart';

/// Elevation tokens extracted from the "Elevation & Depth" section of
/// `designs/sonic_sanctuary_2/DESIGN.md`.
///
/// This design system does NOT use a discrete dp/shadow elevation scale
/// (no Material-style 0-24 levels are defined anywhere in the doc). Depth is
/// built from backdrop blur + glass fill + glow instead, so these tokens
/// name the 5 layers the doc actually describes rather than inventing an
/// elevation-level numbering that isn't there.
class AppElevation {
  AppElevation._();

  // --- Literal from DESIGN.md ---

  /// Layer 1 — Base: solid background color. See AppColors.surface.

  /// Layer 2 — Atmospheric: large, slow-animating radial gradients behind
  /// content. DESIGN.md gives a range, not a single value.
  static const double atmosphericOpacityMin = 0.30;
  static const double atmosphericOpacityMax = 0.40;

  /// Layer 3 — Surface (glass): semi-transparent container fill +
  /// backdrop blur.
  static const Color glassFill = Color(0x0AFFFFFF); // rgba(255,255,255,0.04)
  static const double glassBlurSigma = 20;

  /// Layer 4 — Edge definition: 1px inner border, weighted toward the top
  /// edge, standing in for a drop shadow ("glass edge" / light-from-above).
  static const double glassBorderWidth = 1;

  /// Layer 5 — Active glow: soft outer glow on focused/active elements,
  /// tinted with whatever accent color is contextually active (e.g. the
  /// currently playing track's extracted color).
  static const double glowBlurRadius = 20;
  static const double glowOpacity = 0.3;

  static BoxShadow activeGlow(Color tint) {
    return BoxShadow(
      color: tint.withValues(alpha: glowOpacity),
      blurRadius: glowBlurRadius,
    );
  }

  // --- Derived, not in DESIGN.md — approved as-is 2026-08-17 ---
  // The doc says the layer-4 border is "top-weighted" but never gives an
  // exact opacity (unlike sonic_sanctuary_1, which specifies "white at 20%
  // to transparent" for the equivalent border — that value is NOT reused
  // here since sonic_sanctuary_2 is the canonical doc and didn't restate it).
  static const Color glassBorderTop = Color(0x26FFFFFF); // white @ 15%
  static const Color glassBorderBottom = Color(0x00FFFFFF); // transparent

  /// Ready-to-use top-to-bottom gradient for the layer-4 "glass edge" border
  /// (e.g. as the `gradient` of a `GradientBoxBorder`, or painted directly).
  static const glassBorderGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [glassBorderTop, glassBorderBottom],
  );
}
