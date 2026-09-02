import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/daos/translations_cache_dao.dart';
import 'database_providers.dart';
import 'repository_providers.dart';

/// The user's chosen lyrics-translation target language — null (translation
/// off) until they pick one in Settings > Lyrics.
final translationTargetLanguageProvider = StreamProvider<String?>((ref) async* {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  yield* repo.watchTranslationTargetLanguage();
});

/// Stats for the Settings "Lyrics" screen's translation cache section.
final translationCacheStatsProvider = FutureProvider.autoDispose<TranslationCacheStats>((ref) async {
  final dao = await ref.watch(translationsCacheDaoProvider.future);
  return dao.stats();
});

/// Whether the Now Playing lyrics panel's translate toggle is on — session
/// state, not persisted (defaults to off on every app launch, per CLAUDE.md
/// Phase 5 batch 2). Lives here as a real provider rather than local
/// `State` on `_LyricsLines` (`lyrics_panel.dart`) — unlike
/// `now_playing_screen.dart`'s `_showLyrics` toggle, which never needs to
/// survive this, `_LyricsLines` gets torn down and rebuilt from scratch
/// whenever `LyricsPanel` has to show its loading spinner branch for a
/// newly-selected song whose lyrics aren't already resolved (a `Family`
/// `FutureProvider` keyed on the new song starts at `AsyncLoading`), which
/// happens on essentially every genuine song change. A provider is the only
/// state that reliably survives that teardown for "switch to another song →
/// translations continue without re-toggling" (see CLAUDE.md's verification
/// flow) to actually hold.
final translationEnabledProvider = StateProvider<bool>((ref) => false);
