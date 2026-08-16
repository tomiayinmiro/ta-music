import 'package:flutter/material.dart';

import 'colors.dart';
import 'radius.dart';
import 'typography.dart';

/// Assembled Material 3 [ThemeData] for the app.
///
/// Wires every token from `designs/sonic_sanctuary_2/DESIGN.md`, both the
/// literal ones and the derived ones approved 2026-08-17 (see colors.dart /
/// typography.dart / elevation.dart / motion.dart). Colors and text styles
/// that have a natural home in [ColorScheme]/[TextTheme] are wired there;
/// [AppSemanticColors] covers the colors that don't (success/warning/accent/
/// textTertiary — Material 3's ColorScheme has no slots for these).
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
      extensions: const [AppSemanticColors.dark],
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
    // Every type-scale step defined in typography.dart (literal + derived)
    // is wired here. displayMedium/Small, headlineSmall, and labelLarge have
    // no corresponding AppTypography token (DESIGN.md doesn't define them
    // and none were proposed), so those three slots still inherit Flutter's
    // Material default rather than a guessed value.
    return ThemeData.dark().textTheme.copyWith(
          displayLarge: AppTypography.displayLg.copyWith(color: colorScheme.onSurface),
          headlineLarge: AppTypography.headlineLg.copyWith(color: colorScheme.onSurface),
          headlineMedium: AppTypography.headlineMd.copyWith(color: colorScheme.onSurface),
          titleLarge: AppTypography.titleLg.copyWith(color: colorScheme.onSurface),
          titleMedium: AppTypography.titleMd.copyWith(color: colorScheme.onSurface),
          titleSmall: AppTypography.titleSm.copyWith(color: colorScheme.onSurface),
          bodyLarge: AppTypography.bodyLg.copyWith(color: colorScheme.onSurface),
          bodyMedium: AppTypography.bodyMd.copyWith(color: colorScheme.onSurfaceVariant),
          bodySmall: AppTypography.caption.copyWith(color: colorScheme.onSurfaceVariant),
          labelMedium: AppTypography.labelMd.copyWith(color: colorScheme.onSurfaceVariant),
          labelSmall: AppTypography.labelSm.copyWith(color: colorScheme.onSurfaceVariant),
        );
  }
}

/// Semantic colors with no slot in Material 3's [ColorScheme]. Access via
/// `Theme.of(context).extension<AppSemanticColors>()!`.
///
/// All derived, not in DESIGN.md — approved as-is 2026-08-17. See colors.dart.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.textTertiary,
    required this.accent,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
  });

  static const dark = AppSemanticColors(
    textTertiary: AppColors.textTertiary,
    accent: AppColors.accent,
    success: AppColors.success,
    onSuccess: AppColors.onSuccess,
    warning: AppColors.warning,
    onWarning: AppColors.onWarning,
  );

  final Color textTertiary;
  final Color accent;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;

  @override
  AppSemanticColors copyWith({
    Color? textTertiary,
    Color? accent,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
  }) {
    return AppSemanticColors(
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    );
  }
}
