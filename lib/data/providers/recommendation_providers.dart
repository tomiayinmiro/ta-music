import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../repositories/reactive_query.dart';
import 'repository_providers.dart';

/// Home shows a horizontally-scrollable row of 6-10 cards; "More like this"
/// shows a full list of 15-25 — see Phase 6 batch 1 spec.
const int kHomeRecommendationCount = 8;
const int kMoreLikeThisCount = 20;

/// Settings > Recommendations > "Enable recommendations" — gates both
/// surfaces (Home's "Because you played X" section, the context menu's
/// "More like this" entry). Defaults to true.
final recommendationsEnabledProvider = StreamProvider<bool>((ref) async* {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  yield* repo.watchRecommendationsEnabled();
});

/// Home's auto-picked seed song, or `null` when the section should stay
/// hidden — recommendations disabled, not enough listening history yet, or
/// nothing in recent plays qualifies.
///
/// A reactive `StreamProvider`, not a one-shot `FutureProvider` — Android
/// investigation (2026-09-04): `AppShell`'s `IndexedStack` keeps the Home
/// tab's widget subtree alive for the app's whole life, so this provider
/// only ever gets *watched* once in practice, not rebuilt fresh "on every
/// Lounge open" the way the old doc comment here assumed. A plain
/// `FutureProvider` resolves once and then stays cached forever regardless
/// of new `play_history` rows — reproduced live: two songs played after the
/// Home tab had already resolved a `null` seed (too little history at the
/// time) never surfaced the section at all, because nothing re-ran this
/// provider afterward. `watchQuery` (the same fix already applied to
/// `albumByIdProvider` for the identical bug class) re-emits whenever a
/// write touches any of the tables `RecommendationRepository.homeSeed`
/// actually reads.
final homeRecommendationSeedProvider = StreamProvider<Song?>((ref) async* {
  final enabled = await ref.watch(recommendationsEnabledProvider.future);
  if (!enabled) {
    yield null;
    return;
  }
  final repo = await ref.watch(recommendationRepositoryProvider.future);
  yield* watchQuery(
    {'play_history', 'songs', 'favorites', 'recommendation_seed_cache'},
    repo.homeSeed,
  );
});

/// Ranked recommendations for the Home section's current seed — empty when
/// there's no seed (see [homeRecommendationSeedProvider]). Also reactive
/// (same reasoning as that provider), so the ranking itself picks up new
/// `play_history` co-occurrence data without needing the seed to change.
final homeRecommendationsProvider = StreamProvider<List<Song>>((ref) async* {
  final seed = await ref.watch(homeRecommendationSeedProvider.future);
  if (seed == null) {
    yield const [];
    return;
  }
  final repo = await ref.watch(recommendationRepositoryProvider.future);
  yield* watchQuery(
    {'play_history', 'songs', 'favorites'},
    () => repo.recommendationsFor(seed, limit: kHomeRecommendationCount),
  );
});

/// Ranked recommendations for a user-chosen seed — "More like this" in the
/// song context menu. Keyed on the seed [Song] itself (value-equal, see
/// `Song.==`), so re-opening the screen for the same song reuses the cached
/// result within this provider's lifetime.
final moreLikeThisProvider = FutureProvider.family<List<Song>, Song>((ref, seed) async {
  final repo = await ref.watch(recommendationRepositoryProvider.future);
  return repo.recommendationsFor(seed, limit: kMoreLikeThisCount);
});
