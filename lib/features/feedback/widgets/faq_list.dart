import 'package:flutter/material.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../shared/widgets/glass_container.dart';

class _FaqEntry {
  const _FaqEntry(this.question, this.answer);

  final String question;
  final String answer;
}

const _faqEntries = [
  _FaqEntry(
    'How do I add music to the app?',
    'Music is scanned from folders on your device. Go to Settings > Scanned Folders to add '
        'or remove folders. By default, the app scans your Music folder. You can also exclude '
        "specific folders if you don't want their content shown (like voice memo folders).",
  ),
  _FaqEntry(
    "Why don't I see lyrics for some songs?",
    'The app looks up lyrics from public online databases (LRCLIB and lyrics.ovh). Not every '
        'song is in these databases, especially less popular or newer tracks, and Nigerian/'
        'Afrobeats coverage varies. If lyrics aren\'t found automatically, you can add them '
        'yourself by tapping "Add lyrics manually" on the Now Playing screen — the app will '
        'remember your lyrics for that song.',
  ),
  _FaqEntry(
    'Why are some lyrics wrong or from a different version?',
    'Public lyrics databases sometimes have multiple versions of a song (like a solo version '
        "and a version with featured artists). The app tries to match your file's specific "
        "version using artist name and duration, but sometimes returns a different version's "
        "lyrics. When this happens, you'll see a small warning banner. You can add the correct "
        'lyrics manually.',
  ),
  _FaqEntry(
    'How do translations work?',
    'Lyrics are translated on demand using MyMemory, a free public translation service. Set '
        'your preferred language in Settings > Lyrics > Translation, then toggle translation on '
        'when viewing lyrics. Translation quality varies — some songs (especially with slang, '
        'poetry, or mixed languages) may translate awkwardly.',
  ),
  _FaqEntry(
    "Why doesn't the equalizer work on Windows?",
    "The current audio library we use doesn't support equalizer effects on Windows. It works "
        'on Android where it has full native equalizer support. Windows EQ support may come in '
        'a future version if we swap audio libraries — for now, EQ is Android-only.',
  ),
  _FaqEntry(
    'How does the app decide what to recommend?',
    'Recommendations use only your own listening history — no data leaves your device. The '
        'app looks at which songs you play often, which you favorite, which you skip, and '
        'which songs you tend to play in the same session. Songs that share these signals get '
        'recommended together. The more you use the app, the better recommendations get.',
  ),
  _FaqEntry(
    'What data does the app collect?',
    'Nothing leaves your device. All your listening history, playlists, favorites, and '
        'preferences are stored locally on your phone or computer. The app does connect to '
        'the internet to fetch lyrics (LRCLIB, lyrics.ovh) and translations (MyMemory) — these '
        'services don\'t track you. When you send feedback, the message you type is sent to '
        "the developer's email inbox.",
  ),
  _FaqEntry(
    'What is Aura and how do I level up?',
    'Aura tracks how much time you spend listening on the app. As your total listening '
        'minutes grow, you unlock progression levels (Atmosphere → Aurora → Solar Flare → '
        'Eclipse → Starlight Novice → Nebula Master → Galactic Voyager → Supernova). Only '
        "actual listening time counts — skipping through tracks doesn't inflate your minutes. "
        'Visit the Aura screen to see your current level and progress toward the next one.',
  ),
  _FaqEntry(
    'Can I use the app offline?',
    'Yes for playback — all your music is stored locally, no internet needed to play. Some '
        'features need internet: fetching new lyrics, translating lyrics, and album art from '
        "unusual files. Once lyrics are fetched, they're cached, so replaying a song doesn't "
        'need internet.',
  ),
  _FaqEntry(
    'How do I report a bug or request a feature?',
    "Use the Feedback tab on this screen. Bug reports and feature requests go to the "
        'developer\'s email and get read personally.',
  ),
];

/// Expandable FAQ list for the Help tab of the Feedback & Help screen. Plain
/// accordion built from sonic_sanctuary_2 tokens — no Stitch design exists
/// for this screen, see DESIGN_MAP.md.
class FaqList extends StatelessWidget {
  const FaqList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      itemCount: _faqEntries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.stackSm),
      itemBuilder: (context, index) => _FaqTile(entry: _faqEntries[index]),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.entry});

  final _FaqEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      borderRadius: AppRadius.borderRadiusMd,
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMd),
          collapsedShape: const RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMd),
          title: Text(
            entry.question,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.stackMd,
            0,
            AppSpacing.stackMd,
            AppSpacing.stackMd,
          ),
          expandedAlignment: Alignment.centerLeft,
          children: [
            Text(
              entry.answer,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
