import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../data/models/song.dart';
import '../../../data/providers/aura_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/services/aura_service.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../library/screens/artist_detail_screen.dart';

/// The Aura page's "Local Insights" card: a 7 Days / 1 Month / All Time
/// toggle over Top Artists and Most Played, ranked by plain play count only
/// — no percentiles, per CLAUDE.md's Aura scope. Owns the window selection
/// itself since nothing else on the page needs it.
class AuraLocalInsightsCard extends ConsumerStatefulWidget {
  const AuraLocalInsightsCard({super.key});

  @override
  ConsumerState<AuraLocalInsightsCard> createState() => _AuraLocalInsightsCardState();
}

class _AuraLocalInsightsCardState extends ConsumerState<AuraLocalInsightsCard> {
  AuraTimeWindow _window = AuraTimeWindow.sevenDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topArtistsAsync = ref.watch(auraTopArtistsProvider(_window));
    final mostPlayedAsync = ref.watch(auraMostPlayedProvider(_window));

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Local Insights', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.stackMd),
          _WindowToggle(selected: _window, onChanged: (w) => setState(() => _window = w)),
          const SizedBox(height: AppSpacing.stackMd),
          Text(
            'TOP ARTISTS',
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          topArtistsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => const Text('Top artists unavailable'),
            data: (artists) {
              if (artists.isEmpty) return const _EmptyInsight();
              return Column(
                children: [
                  for (final stat in artists)
                    _ArtistRow(name: stat.name, playCount: stat.playCount),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.stackMd),
          Divider(color: theme.dividerColor.withValues(alpha: 0.4)),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            'MOST PLAYED',
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          mostPlayedAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => const Text('Most played unavailable'),
            data: (songs) {
              if (songs.isEmpty) return const _EmptyInsight();
              return Column(
                children: [
                  for (final stat in songs)
                    _SongRow(stat: stat, queueContext: [for (final s in songs) s.song]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WindowToggle extends StatelessWidget {
  const _WindowToggle({required this.selected, required this.onChanged});

  final AuraTimeWindow selected;
  final ValueChanged<AuraTimeWindow> onChanged;

  static const _labels = {
    AuraTimeWindow.sevenDays: '7 Days',
    AuraTimeWindow.oneMonth: '1 Month',
    AuraTimeWindow.allTime: 'All Time',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.3),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final window in AuraTimeWindow.values)
            GestureDetector(
              onTap: () => onChanged(window),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: window == selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: AppRadius.borderRadiusFull,
                ),
                child: Text(
                  _labels[window]!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: window == selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArtistRow extends ConsumerWidget {
  const _ArtistRow({required this.name, required this.playCount});

  final String name;
  final int playCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: AppRadius.borderRadiusMd,
      onTap: () async {
        final repo = await ref.read(artistRepositoryProvider.future);
        final artist = await repo.findByName(name);
        if (artist != null && context.mounted) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: artist)));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              child: Icon(Icons.person_rounded, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: Text(name, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
            ),
            Text('$playCount plays', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _SongRow extends ConsumerWidget {
  const _SongRow({required this.stat, required this.queueContext});

  final AuraSongPlayStat stat;
  final List<Song> queueContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: AppRadius.borderRadiusMd,
      onTap: () => ref.read(playbackServiceProvider).playFromSong(stat.song, queueContext),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                stat.song.displayTitle,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('${stat.playCount} Plays', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _EmptyInsight extends StatelessWidget {
  const _EmptyInsight();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
      child: Text('Play something to see this here.', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
