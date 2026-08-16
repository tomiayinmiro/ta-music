import 'package:flutter/material.dart';

import 'colors.dart';
import 'radius.dart';
import 'typography.dart';

/// Assembled Material 3 [ThemeData] for the app.
///
/// Only wires tokens that came directly from `designs/sonic_sanctuary_2/
/// DESIGN.md` (see colors.dart / typography.dart "Literal" sections). The
/// PROPOSED tokens (success/warning/accent colors, title/caption/overline
/// type styles, motion durations, glass border opacity) are intentionally
/// NOT used here yet — pending sign-off, slots they'd fill just inherit
/// Flutter's Material defaults instead of a guessed value.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final colorScheme = _colorScheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: _textTheme(colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusLg,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusRegular,
          ),
        ),
      ),
    );
  }

  static ColorScheme get _colorScheme => const ColorScheme(
        brightness: Brightness.dark,
        surface: AppColors.surface,
        surfaceDim: AppColors.surfaceDim,
        surfaceBright: AppColors.surfaceBright,
        surfaceContainerLowest: AppColors.surfaceContainerLowest,
        surfaceContainerLow: AppColors.surfaceContainerLow,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerHigh: AppColors.surfaceContainerHigh,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        surfaceTint: AppColors.surfaceTint,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        inversePrimary: AppColors.inversePrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        primaryFixed: AppColors.primaryFixed,
        primaryFixedDim: AppColors.primaryFixedDim,
        onPrimaryFixed: AppColors.onPrimaryFixed,
        onPrimaryFixedVariant: AppColors.onPrimaryFixedVariant,
        secondaryFixed: AppColors.secondaryFixed,
        secondaryFixedDim: AppColors.secondaryFixedDim,
        onSecondaryFixed: AppColors.onSecondaryFixed,
        onSecondaryFixedVariant: AppColors.onSecondaryFixedVariant,
        tertiaryFixed: AppColors.tertiaryFixed,
        tertiaryFixedDim: AppColors.tertiaryFixedDim,
        onTertiaryFixed: AppColors.onTertiaryFixed,
        onTertiaryFixedVariant: AppColors.onTertiaryFixedVariant,
      );

  static TextTheme _textTheme(ColorScheme colorScheme) {
    // Only the type-scale steps DESIGN.md actually defines are overridden.
    // Every other TextTheme slot (titleLarge, bodySmall, labelLarge, ...)
    // is intentionally left as Flutter's Material default until the
    // PROPOSED steps in typography.dart are confirmed.
    return ThemeData.dark().textTheme.copyWith(
          displayLarge: AppTypography.displayLg.copyWith(color: colorScheme.onSurface),
          headlineLarge: AppTypography.headlineLg.copyWith(color: colorScheme.onSurface),
          headlineMedium: AppTypography.headlineMd.copyWith(color: colorScheme.onSurface),
          bodyLarge: AppTypography.bodyLg.copyWith(color: colorScheme.onSurface),
          bodyMedium: AppTypography.bodyMd.copyWith(color: colorScheme.onSurfaceVariant),
          labelMedium: AppTypography.labelMd.copyWith(color: colorScheme.onSurfaceVariant),
          labelSmall: AppTypography.labelSm.copyWith(color: colorScheme.onSurfaceVariant),
        );
  }
}
