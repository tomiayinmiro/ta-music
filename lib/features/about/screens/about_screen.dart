import 'package:flutter/material.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass_container.dart';

/// Reached from the nav drawer's "About" entry. Static app-info content —
/// no Stitch design exists for this screen (see DESIGN_MAP.md); built from
/// sonic_sanctuary_2 tokens matching Settings/Feedback & Help's section
/// layout. The app-icon image is the current Android launcher icon copied
/// into `assets/images/app_icon.png` — there's no real app icon yet, see
/// the "Replace app icon before release" BACKLOG.md item.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _acknowledgments = [
    (name: 'Flutter', description: "Google's UI toolkit"),
    (name: 'LRCLIB (lrclib.net)', description: 'Lyrics database'),
    (name: 'lyrics.ovh', description: 'Fallback lyrics source'),
    (name: 'MyMemory (mymemory.translated.net)', description: 'Translation service'),
    (name: 'just_audio', description: 'Audio playback engine'),
    (name: 'audio_service', description: 'Media session integration'),
    (name: 'Web3Forms', description: 'Feedback submission service'),
    (
      name: 'The many other open-source Dart and Flutter packages',
      description: 'that make this app possible',
    ),
  ];

  static const _releaseHighlights = [
    'Local music library with folder scanning',
    'Karaoke-style lyrics with automatic translation',
    'Personal listening recommendations',
    'Aura listening progression system',
    'Android equalizer with custom presets',
    'Album cover art with fallback images',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: AppRadius.borderRadiusLg,
              child: Image.asset('assets/images/app_icon.png', width: 96, height: 96),
            ),
          ),
          const SizedBox(height: AppSpacing.stackMd),
          Center(child: Text('TA MUSIC', style: theme.textTheme.headlineMedium)),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            'Cross-platform offline music player for Android and Windows. All your music, '
            'lyrics, and listening data live on your device.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.stackLg),

          _SectionLabel('MADE BY'),
          const SizedBox(height: AppSpacing.stackSm),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.stackMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Made by Tomi Ayinmiro', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  'Built with Flutter',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),

          _SectionLabel('PRIVACY'),
          const SizedBox(height: AppSpacing.stackSm),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.stackMd),
            child: Text(
              'All data stays on your device. TA MUSIC does not collect, track, or transmit '
              'your usage data, listening history, or personal information. Internet '
              'connection is only used to fetch lyrics and translations, which are cached '
              'locally after fetching.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),

          _SectionLabel('OPEN SOURCE ACKNOWLEDGMENTS'),
          const SizedBox(height: AppSpacing.stackSm),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.stackMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TA MUSIC is built with and gratefully uses:',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.stackSm),
                for (final entry in _acknowledgments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall,
                        children: [
                          TextSpan(
                            text: '${entry.name} — ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: entry.description),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),

          _SectionLabel('RELEASE NOTES'),
          const SizedBox(height: AppSpacing.stackSm),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.stackMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version 1.0.0 — Initial public release', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.stackSm),
                for (final highlight in _releaseHighlights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('•  $highlight', style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: AppTypography.overline.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
