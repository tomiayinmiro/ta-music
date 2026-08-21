import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/models/aura_level.dart';
import '../../../data/providers/aura_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../library/providers/shell_scaffold_key_provider.dart';
import '../../library/providers/shell_tab_provider.dart';
import '../widgets/aura_level_card.dart';
import '../widgets/aura_local_insights_card.dart';
import '../widgets/aura_profile_header.dart';
import '../widgets/aura_stats_card.dart';
import 'level_up_transition_screen.dart';

/// The Aura page — the bottom nav's 3rd tab (replacing Favorites, approved
/// 2026-08-21). Matches `designs/aura/local_stats/`: profile header, level
/// progress card, stats card, and windowed Local Insights. Local-only
/// listening-minutes leveling, per CLAUDE.md's Aura gamification scope — no
/// accounts, no percentiles, no social sharing.
class AuraScreen extends ConsumerStatefulWidget {
  const AuraScreen({super.key});

  @override
  ConsumerState<AuraScreen> createState() => _AuraScreenState();
}

class _AuraScreenState extends ConsumerState<AuraScreen> {
  /// Recomputes, and — if the fresh level exceeds the last one shown —
  /// plays the level-up transition before committing `last_shown_level`.
  /// Runs every time the Aura tab becomes active (see the `ref.listen`
  /// below), not just once per app session: `AppShell`'s `IndexedStack`
  /// keeps this widget alive across tab switches, so `initState` alone
  /// would only ever fire once.
  ///
  /// Comparing the post-recompute `currentLevel` directly against
  /// `lastShownLevel` (rather than walking level-by-level) is what makes a
  /// multi-level jump show the transition for the highest level reached
  /// only. Persisting `lastShownLevel` unconditionally after the push
  /// returns — whether the user watched it out or tapped to skip — is what
  /// stops it from replaying next time.
  Future<void> _onAuraOpened() async {
    final service = await ref.read(auraServiceProvider.future);
    final state = await service.recompute();
    if (state.currentLevel <= state.lastShownLevel || !mounted) return;

    final newLevel = AuraLevel.fromNumber(state.currentLevel);
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LevelUpTransitionScreen(level: newLevel),
      ),
    );
    await service.markLevelShown(state.currentLevel);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(shellTabIndexProvider, (previous, next) {
      if (next == 2 && previous != 2) _onAuraOpened();
    });

    final auraStateAsync = ref.watch(auraStateProvider);
    final distinctSongsPlayedAsync = ref.watch(auraDistinctSongsPlayedProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => ref.read(shellScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: const Text('Aura'),
      ),
      body: auraStateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (state) {
          final level = AuraLevel.fromNumber(state.currentLevel);
          final progress = progressToNext(state.totalListeningMinsCached);
          final totalSongsPlayed = distinctSongsPlayedAsync.valueOrNull ?? 0;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            children: [
              AuraProfileHeader(level: level),
              const SizedBox(height: AppSpacing.stackLg),
              AuraLevelCard(progress: progress),
              const SizedBox(height: AppSpacing.stackMd),
              AuraStatsCard(
                totalMinutes: state.totalListeningMinsCached,
                totalSongsPlayed: totalSongsPlayed,
              ),
              const SizedBox(height: AppSpacing.stackMd),
              const AuraLocalInsightsCard(),
            ],
          );
        },
      ),
    );
  }
}
