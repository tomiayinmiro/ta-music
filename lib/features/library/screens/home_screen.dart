import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/utils/playback_stub.dart';
import '../../../data/models/song.dart';
import '../../../data/providers/library_providers.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../providers/shell_tab_provider.dart';
import '../screens/recently_added_screen.dart';
import '../../settings/screens/settings_screen.dart';

/// Home / "Lounge" — matches `designs/lounge_home/`, reinterpreted per the
/// 2026-08-17 plan: the editorial "Featured" hero + mood "Vibe" chips (no
/// curator or mood-tagging data source exists locally) become a
/// "Continue Listening" hero driven by the most recently played song, and
/// quick access links to Favorites + Recently Added (Playlists dropped —
/// not built until Phase 4).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final librarySizeAsync = ref.watch(librarySizeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('TA MUSIC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Search is coming in a later phase.')),
            ),
          ),
        ],
      ),
      body: librarySizeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (size) {
          if (size == 0) {
            return EmptyState(
              icon: Icons.library_music_outlined,
              title: 'Your library is empty',
              message: 'Pick folders to scan for music and TA MUSIC will do the rest.',
              actionLabel: 'Choose folders',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            );
          }
          return const _HomeContent();
        },
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentlyPlayedAsync = ref.watch(recentlyPlayedSongsProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.containerMargin,
        vertical: AppSpacing.stackMd,
      ),
      children: [
        recentlyPlayedAsync.when(
          loading: () => const SizedBox(height: 180),
          error: (_, _) => const SizedBox.shrink(),
          data: (songs) => songs.isEmpty
              ? const _WelcomeHero()
              : _ContinueListeningHero(song: songs.first),
        ),
        const SizedBox(height: AppSpacing.stackLg),
        Row(
          children: [
            Expanded(
              child: _QuickAccessTile(
                icon: Icons.favorite_rounded,
                label: 'Favorites',
                onTap: () => ref.read(shellTabIndexProvider.notifier).set(2),
              ),
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: _QuickAccessTile(
                icon: Icons.new_releases_rounded,
                label: 'Recently Added',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecentlyAddedScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.stackLg),
        recentlyPlayedAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (songs) {
            if (songs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Recently Played'),
                const SizedBox(height: AppSpacing.stackSm),
                SizedBox(
                  height: 188,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: songs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.stackSm),
                    itemBuilder: (context, i) {
                      final song = songs[i];
                      return SizedBox(
                        width: 128,
                        child: GestureDetector(
                          onTap: () => playSongStub(context, ref, song),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CoverArt(path: null, size: 128),
                              const SizedBox(height: AppSpacing.stackSm),
                              Text(
                                song.displayTitle,
                                style: Theme.of(context).textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                song.displayArtist,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: AppRadius.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome to your library', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            'Head to The Gallery and play something — it\'ll show up here next time.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ContinueListeningHero extends ConsumerWidget {
  const _ContinueListeningHero({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: AppRadius.borderRadiusLg,
      ),
      child: Row(
        children: [
          const CoverArt(path: null, size: 88),
          const SizedBox(width: AppSpacing.stackMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Continue Listening', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  song.displayTitle,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  song.displayArtist,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.stackSm),
                FilledButton.icon(
                  onPressed: () => playSongStub(context, ref, song),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.stackMd),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: AppRadius.borderRadiusMd,
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
          ],
        ),
      ),
    );
  }
}
