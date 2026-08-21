import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/models/aura_level.dart';
import '../../../shared/widgets/glass_container.dart';

/// The celebration screen played when [AuraState.currentLevel] exceeds
/// [AuraState.lastShownLevel] — matches `designs/aura/level_up_transition/`:
/// a floating glowing badge (the new level's own bundled image, in place of
/// the mockup's generic icon), spinning rings, a gradient headline, and the
/// level's description from `AuraLevel.tagline`.
///
/// Deliberately a bare `Scaffold`, not `AppScaffold` — like `NowPlayingScreen`,
/// this is a full-screen takeover moment, not a normal content screen a mini
/// player should show underneath.
///
/// Tapping anywhere (the button included) dismisses it. [AuraScreen] awaits
/// the push and persists `last_shown_level` right after, regardless of
/// whether the animation played out or was skipped immediately — see
/// `AuraScreen._onAuraOpened`.
class LevelUpTransitionScreen extends StatelessWidget {
  const LevelUpTransitionScreen({super.key, required this.level});

  final AuraLevel level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      theme.colorScheme.surface,
                    ],
                    radius: 0.9,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.containerMargin),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Badge(level: level),
                      const SizedBox(height: AppSpacing.stackLg),
                      GlassContainer(
                        padding: const EdgeInsets.all(AppSpacing.containerMargin),
                        child: Column(
                          children: [
                            // displayLarge (48px) doesn't fit every level
                            // name at this panel's width — "Atmosphere"
                            // wrapped mid-word without this. FittedBox
                            // scales the whole name down to fit instead,
                            // so short names still render at full size.
                            // displayLarge (48px) doesn't fit every level
                            // name at this panel's width — "Atmosphere",
                            // "Starlight Novice", and "Galactic Voyager" all
                            // overflowed without this. FittedBox scales the
                            // whole name down to fit instead, so short names
                            // still render at full size. See
                            // test/features/aura/level_up_transition_screen_test.dart.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
                                ).createShader(bounds),
                                child: Text(
                                  level.displayName,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.displayLarge?.copyWith(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackSm),
                            Text(
                              'Aura Level Up',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.stackSm),
                            Text(
                              level.tagline,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.stackLg),
                      _ContinueButton(onTap: () => Navigator.of(context).pop()),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.level});

  final AuraLevel level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(theme.colorScheme.primary, 220, 15000),
          _ring(theme.colorScheme.secondary, 190, 20000, reverse: true),
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.primaryContainer, width: 2),
              boxShadow: [
                BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.5), blurRadius: 40),
              ],
            ),
            child: ClipOval(child: Image.asset(level.imageAssetPath, fit: BoxFit.cover)),
          ),
        ],
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -12, duration: 3.seconds, curve: Curves.easeInOut),
    );
  }

  Widget _ring(Color color, double size, int durationMs, {bool reverse = false}) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: 0.75,
        strokeWidth: 1.5,
        color: color.withValues(alpha: 0.4),
        backgroundColor: Colors.transparent,
      ),
    ).animate(onPlay: (c) => c.repeat()).rotate(
          duration: Duration(milliseconds: durationMs),
          begin: reverse ? 1 : 0,
          end: reverse ? 0 : 1,
        );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(999),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CONTINUE',
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 18, color: theme.colorScheme.onSurface),
          ],
        ),
      ),
    );
  }
}
