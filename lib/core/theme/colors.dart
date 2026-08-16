import 'package:flutter/widgets.dart';

/// Color tokens extracted from `designs/sonic_sanctuary_2/DESIGN.md`.
///
/// The DESIGN.md palette is a literal Material 3 `ColorScheme` export (every
/// key below matches an M3 ColorScheme field name 1:1) — see `_colorScheme`
/// in `theme_data.dart`, which assembles these into a real `ColorScheme`.
///
/// The second block was not present in DESIGN.md and was derived to satisfy
/// fields the brief asked for (text hierarchy, accent, success, warning) that
/// the design doc doesn't define. Approved as-is 2026-08-16 — wired into
/// `ThemeData.extensions` via `AppSemanticColors` in `theme_data.dart`.
class AppColors {
  AppColors._();

  // --- Literal from DESIGN.md ---
  static const surface = Color(0xFF131313);
  static const surfaceDim = Color(0xFF131313);
  static const surfaceBright = Color(0xFF393939);
  static const surfaceContainerLowest = Color(0xFF0E0E0E);
  static const surfaceContainerLow = Color(0xFF1C1B1B);
  static const surfaceContainer = Color(0xFF201F1F);
  static const surfaceContainerHigh = Color(0xFF2A2A2A);
  static const surfaceContainerHighest = Color(0xFF353534);
  static const onSurface = Color(0xFFE5E2E1);
  static const onSurfaceVariant = Color(0xFFCCC3D8);
  static const inverseSurface = Color(0xFFE5E2E1);
  static const inverseOnSurface = Color(0xFF313030);
  static const outline = Color(0xFF958DA1);
  static const outlineVariant = Color(0xFF4A4455);
  static const surfaceTint = Color(0xFFD2BBFF);

  static const primary = Color(0xFFD2BBFF);
  static const onPrimary = Color(0xFF3F008E);
  static const primaryContainer = Color(0xFF7C3AED);
  static const onPrimaryContainer = Color(0xFFEDE0FF);
  static const inversePrimary = Color(0xFF732EE4);

  static const secondary = Color(0xFF4CD7F6);
  static const onSecondary = Color(0xFF003640);
  static const secondaryContainer = Color(0xFF03B5D3);
  static const onSecondaryContainer = Color(0xFF00424E);

  static const tertiary = Color(0xFFFFB784);
  static const onTertiary = Color(0xFF4F2500);
  static const tertiaryContainer = Color(0xFFA15100);
  static const onTertiaryContainer = Color(0xFFFFE0CD);

  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);

  static const primaryFixed = Color(0xFFEADDFF);
  static const primaryFixedDim = Color(0xFFD2BBFF);
  static const onPrimaryFixed = Color(0xFF25005A);
  static const onPrimaryFixedVariant = Color(0xFF5A00C6);

  static const secondaryFixed = Color(0xFFACEDFF);
  static const secondaryFixedDim = Color(0xFF4CD7F6);
  static const onSecondaryFixed = Color(0xFF001F26);
  static const onSecondaryFixedVariant = Color(0xFF004E5C);

  static const tertiaryFixed = Color(0xFFFFDCC6);
  static const tertiaryFixedDim = Color(0xFFFFB784);
  static const onTertiaryFixed = Color(0xFF301400);
  static const onTertiaryFixedVariant = Color(0xFF713700);

  static const background = Color(0xFF131313);
  static const onBackground = Color(0xFFE5E2E1);
  static const surfaceVariant = Color(0xFF353534);

  // --- Derived, not in DESIGN.md ---
  // Text hierarchy: DESIGN.md defines onSurface/onSurfaceVariant but no third
  // step. Derived as onSurface at reduced opacity rather than a new hex, so it
  // stays tonally locked to onSurface instead of introducing an unrelated color.
  static const textPrimary = onSurface;
  static const textSecondary = onSurfaceVariant;
  static const textTertiary = Color(0x99E5E2E1); // onSurface @ 60% alpha

  // Accent: DESIGN.md's prose describes primary+secondary as "glows and
  // highlights" with no separate "accent" concept. Aliased to secondary
  // (the cooler, higher-contrast of the two) as the closest fit.
  static const accent = secondary;

  // Success / warning: absent from DESIGN.md entirely (Material 3 doesn't
  // define these natively either). Hand-picked to match the palette's
  // saturation/lightness range rather than using generic Material red/green.
  static const success = Color(0xFF4ADE9A);
  static const onSuccess = Color(0xFF003820);
  static const warning = Color(0xFFFFB020);
  static const onWarning = Color(0xFF3F2600);
}
