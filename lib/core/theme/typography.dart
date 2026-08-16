import 'package:flutter/widgets.dart';

/// Font family names as declared in pubspec.yaml's `fonts:` section.
/// Both are bundled as single variable-weight TTFs (see assets/fonts/) —
/// exact weights are selected per-style via [TextStyle.fontVariations]
/// rather than shipping one static file per weight.
class AppFontFamilies {
  AppFontFamilies._();

  static const sora = 'Sora';
  static const hankenGrotesk = 'Hanken Grotesk';
}

/// Type scale extracted from `designs/sonic_sanctuary_2/DESIGN.md`.
///
/// `letterSpacing` in DESIGN.md is expressed in `em`; Flutter's
/// [TextStyle.letterSpacing] wants logical pixels, so each em value below
/// was converted as `em * fontSize`.
class AppTypography {
  AppTypography._();

  // --- Literal from DESIGN.md ---

  static const displayLg = TextStyle(
    fontFamily: AppFontFamilies.sora,
    fontVariations: [FontVariation('wght', 700)],
    fontWeight: FontWeight.w700,
    fontSize: 48,
    height: 56 / 48,
    letterSpacing: -0.96, // -0.02em
  );

  static const headlineLg = TextStyle(
    fontFamily: AppFontFamilies.sora,
    fontVariations: [FontVariation('wght', 600)],
    fontWeight: FontWeight.w600,
    fontSize: 32,
    height: 40 / 32,
    letterSpacing: -0.32, // -0.01em
  );

  static const headlineLgMobile = TextStyle(
    fontFamily: AppFontFamilies.sora,
    fontVariations: [FontVariation('wght', 600)],
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 36 / 28,
  );

  static const headlineMd = TextStyle(
    fontFamily: AppFontFamilies.sora,
    fontVariations: [FontVariation('wght', 600)],
    fontWeight: FontWeight.w600,
    fontSize: 24,
    height: 32 / 24,
  );

  static const bodyLg = TextStyle(
    fontFamily: AppFontFamilies.hankenGrotesk,
    fontVariations: [FontVariation('wght', 400)],
    fontWeight: FontWeight.w400,
    fontSize: 18,
    height: 28 / 18,
  );

  static const bodyMd = TextStyle(
    fontFamily: AppFontFamilies.hankenGrotesk,
    fontVariations: [FontVariation('wght', 400)],
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 24 / 16,
  );

  static const labelMd = TextStyle(
    fontFamily: AppFontFamilies.hankenGrotesk,
    fontVariations: [FontVariation('wght', 600)],
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.7, // 0.05em
  );

  static const labelSm = TextStyle(
    fontFamily: AppFontFamilies.hankenGrotesk,
    fontVariations: [FontVariation('wght', 500)],
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.24, // 0.02em
  );

  // --- PROPOSED, not in DESIGN.md — confirm before use ---
  // DESIGN.md has no "title", "caption", or "overline" step, and only one
  // display size / two headline sizes. These fill the gaps the brief asked
  // for (title, caption, overline), sized to slot between the existing
  // steps and reusing the same two font families and weight logic.

  static const titleLg = TextStyle(
    fontFamily: AppFontFamilies.sora,
    fontVariations: [FontVariation('wght', 600)],
    fontWeight: FontWeight.w600,
    fontSize: 20,
    height: 28 / 20,
    letterSpacing: -0.1,
  );

  static const titleMd = TextStyle(
    fontFamily: AppFontFamilies.sora,
    fontVariations: [FontVariation('wght', 600)],
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 24 / 16,
  );

  static const titleSm = TextStyle(
    fontFamily: AppFontFamilies.sora,
    fontVariations: [FontVariation('wght', 600)],
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 20 / 14,
  );

  static const caption = TextStyle(
    fontFamily: AppFontFamilies.hankenGrotesk,
    fontVariations: [FontVariation('wght', 400)],
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 16 / 12,
  );

  static const overline = TextStyle(
    fontFamily: AppFontFamilies.hankenGrotesk,
    fontVariations: [FontVariation('wght', 600)],
    fontWeight: FontWeight.w600,
    fontSize: 11,
    height: 16 / 11,
    letterSpacing: 0.88, // 0.08em
  );
}
