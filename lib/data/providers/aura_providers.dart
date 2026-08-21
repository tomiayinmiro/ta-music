import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/aura_state.dart';
import '../services/aura_service.dart';
import 'repository_providers.dart';

// Hand-written providers rather than `@riverpod` codegen — see
// `lib/data/models/song.dart` for why.

/// The cached Aura state, watched reactively. Reflects whatever's in
/// `aura_state` right now — callers that need fresh numbers (the Aura page,
/// on open) call `AuraService.recompute()` first.
final auraStateProvider = StreamProvider<AuraState>((ref) async* {
  final service = await ref.watch(auraServiceProvider.future);
  yield* service.watch();
});

final auraTopArtistsProvider = StreamProvider.family<List<AuraArtistStat>, AuraTimeWindow>((
  ref,
  window,
) async* {
  final service = await ref.watch(auraServiceProvider.future);
  yield* service.watchTopArtists(window);
});

final auraMostPlayedProvider = StreamProvider.family<List<AuraSongPlayStat>, AuraTimeWindow>((
  ref,
  window,
) async* {
  final service = await ref.watch(auraServiceProvider.future);
  yield* service.watchMostPlayedSongs(window);
});

/// All-time distinct songs played — the Aura Stats card's "Songs Played"
/// tile. Deliberately not window-filtered, matching total minutes (the
/// other Aura Stats number) — only Local Insights below it reacts to the
/// 7 Days / 1 Month / All Time toggle.
final auraDistinctSongsPlayedProvider = StreamProvider<int>((ref) async* {
  final service = await ref.watch(auraServiceProvider.future);
  yield* service.watchDistinctSongsPlayed();
});
