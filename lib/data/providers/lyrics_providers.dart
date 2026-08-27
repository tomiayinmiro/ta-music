import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/daos/lyrics_cache_dao.dart';
import '../models/song.dart';
import '../repositories/lyrics_repository.dart';
import 'database_providers.dart';
import 'repository_providers.dart';

/// Looks up lyrics for [song] — keyed on the whole [Song] (via its `==`,
/// artist/title/album/path/durationMs all included) rather than just an id,
/// matching [LyricsRepository]'s own (artist, title) cache key closely
/// enough that two songs sharing metadata still share this in-memory
/// result. `autoDispose`: the lyrics panel is only mounted while the user
/// has it open, so there's no reason to keep a fetch result alive once they
/// close it — the background prefetch path (`LyricsPrefetchService`) is
/// entirely separate and keeps the DB cache warm regardless of whether this
/// provider is ever watched.
final lyricsForSongProvider = FutureProvider.family.autoDispose<LyricsResult, Song>((
  ref,
  song,
) async {
  final repo = await ref.watch(lyricsRepositoryProvider.future);
  return repo.getLyrics(
    artist: song.artist,
    title: song.title,
    album: song.album,
    duration: song.durationMs != null ? song.duration : null,
    audioFilePath: song.path,
  );
});

/// Stats for the Settings "Lyrics" screen.
final lyricsCacheStatsProvider = FutureProvider.autoDispose<LyricsCacheStats>((ref) async {
  final dao = await ref.watch(lyricsCacheDaoProvider.future);
  return dao.stats();
});

/// The user's manually-added lyrics entries, for the Settings "Lyrics"
/// screen's management list.
final manualLyricsEntriesProvider = FutureProvider.autoDispose<List<ManualLyricsEntry>>((
  ref,
) async {
  final repo = await ref.watch(lyricsRepositoryProvider.future);
  return repo.getManualLyricsEntries();
});
