import '../database/daos/aura_state_dao.dart';
import '../database/daos/listening_segment_dao.dart';
import '../database/daos/play_history_dao.dart';
import '../database/daos/settings_dao.dart';
import '../database/daos/song_dao.dart';
import '../models/aura_level.dart';
import '../models/aura_state.dart';
import '../models/song.dart';
import '../repositories/reactive_query.dart';
import '../repositories/settings_repository.dart';

/// The time windows Local Insights can be filtered by.
enum AuraTimeWindow { sevenDays, oneMonth, allTime }

extension _AuraTimeWindowSince on AuraTimeWindow {
  /// The `since` cutoff for [PlayHistoryDao]'s windowed queries, or `null`
  /// for all-time. Both windows are rolling (not calendar-aligned), for
  /// consistency between the two and to avoid the "shrinks to nothing on
  /// the 1st" edge case a calendar month would have.
  DateTime? sinceFrom(DateTime now) => switch (this) {
    AuraTimeWindow.sevenDays => now.subtract(const Duration(days: 7)),
    AuraTimeWindow.oneMonth => now.subtract(const Duration(days: 30)),
    AuraTimeWindow.allTime => null,
  };
}

/// One local artist's play count within an Aura Local Insights window. Plain
/// play-count ranking only — no percentiles, per CLAUDE.md's Aura scope.
class AuraArtistStat {
  const AuraArtistStat({required this.name, required this.playCount});

  final String name;
  final int playCount;
}

/// One local song's play count within an Aura Local Insights window.
class AuraSongStat {
  const AuraSongStat({required this.songId, required this.playCount});

  final int songId;
  final int playCount;
}

/// A [Song] paired with its play count — what the Most Played list actually
/// renders (title + tap-to-play need the full song, not just its id).
class AuraSongPlayStat {
  const AuraSongPlayStat({required this.song, required this.playCount});

  final Song song;
  final int playCount;
}

/// Computes and caches the local Aura level state from `play_history`, and
/// serves the windowed Local Insights lists. Fully local — no accounts, no
/// network, no cross-user data (see CLAUDE.md's Aura gamification scope).
class AuraService {
  AuraService({
    required this._auraStateDao,
    required this._playHistoryDao,
    required this._songDao,
    required this._listeningSegmentDao,
    required this._settingsDao,
  });

  final AuraStateDao _auraStateDao;
  final PlayHistoryDao _playHistoryDao;
  final SongDao _songDao;
  final ListeningSegmentDao _listeningSegmentDao;
  final SettingsDao _settingsDao;

  /// Reactively reads the cached [AuraState] — does not recompute. Callers
  /// that need fresh numbers (the Aura page, on open) call [recompute]
  /// first; this just reflects whatever's currently cached.
  Stream<AuraState> watch() => watchQuery({'aura_state'}, currentState);

  Future<AuraState> currentState() async {
    final row = await _auraStateDao.load();
    return row == null ? AuraState.initial : AuraState.fromMap(row);
  }

  /// Recomputes total listening minutes and persists the refreshed cache.
  /// Only `total_listening_mins_cached`, `current_level`, and
  /// `last_computed_at` are touched here — `last_shown_level` is the
  /// level-up transition's own concern, not this recompute's.
  ///
  /// Sourced from `listening_segments` (real, wall-clock-measured time),
  /// not `play_history` — see `_migrationV6`'s doc for why a track's full
  /// duration must never be credited for a partial listen. Also folds in
  /// any minutes carried over from a backup import (see
  /// `SettingsRepository.importedAuraMinutesOffsetKey`) — those minutes
  /// aren't reflected in this device's own `listening_segments` at all, so
  /// without adding them back in here every recompute would silently erase
  /// an imported total the moment the Aura page is opened again.
  Future<AuraState> recompute() async {
    final totalMs = await _listeningSegmentDao.totalListenedMs();
    final importedOffsetRaw = await _settingsDao.get(
      SettingsRepository.importedAuraMinutesOffsetKey,
    );
    final importedOffsetMinutes = importedOffsetRaw != null
        ? (int.tryParse(importedOffsetRaw) ?? 0)
        : 0;
    final totalMinutes = totalMs ~/ 60000 + importedOffsetMinutes;
    final level = currentLevelFromMinutes(totalMinutes);
    final existing = await currentState();
    final next = existing.copyWith(
      totalListeningMinsCached: totalMinutes,
      currentLevel: level.number,
      lastComputedAt: DateTime.now(),
    );
    await _auraStateDao.save(next.toMap());
    return next;
  }

  /// All-time distinct songs played — the Aura Stats card's "Songs Played"
  /// tile. `COUNT(DISTINCT song_id)`, not a raw play count: playing one
  /// song ten times must read as "1 song played."
  Future<int> distinctSongsPlayed() => _playHistoryDao.distinctSongsPlayed();

  Stream<int> watchDistinctSongsPlayed() =>
      watchQuery({'play_history'}, distinctSongsPlayed);

  /// Records that the level-up transition has been shown for [level] —
  /// called once the transition is dismissed (played through or skipped),
  /// so re-opening the Aura page doesn't replay it. Leaves the cached
  /// minutes/level untouched.
  Future<AuraState> markLevelShown(int level) async {
    final existing = await currentState();
    final next = existing.copyWith(lastShownLevel: level);
    await _auraStateDao.save(next.toMap());
    return next;
  }

  Future<List<AuraArtistStat>> topArtists(AuraTimeWindow window, {int limit = 5}) async {
    final pairs = await _playHistoryDao.topArtists(
      limit: limit,
      since: window.sinceFrom(DateTime.now()),
    );
    return [for (final (name, plays) in pairs) AuraArtistStat(name: name, playCount: plays)];
  }

  Stream<List<AuraArtistStat>> watchTopArtists(AuraTimeWindow window, {int limit = 5}) {
    return watchQuery({'play_history', 'songs'}, () => topArtists(window, limit: limit));
  }

  Future<List<AuraSongStat>> mostPlayed(AuraTimeWindow window, {int limit = 5}) async {
    final pairs = await _playHistoryDao.topSongIds(
      limit: limit,
      since: window.sinceFrom(DateTime.now()),
    );
    return [for (final (songId, plays) in pairs) AuraSongStat(songId: songId, playCount: plays)];
  }

  Stream<List<AuraSongStat>> watchMostPlayed(AuraTimeWindow window, {int limit = 5}) {
    return watchQuery({'play_history'}, () => mostPlayed(window, limit: limit));
  }

  /// [mostPlayed] resolved to full [Song] rows — what the Aura page's Most
  /// Played list actually renders. Songs that no longer resolve (deleted
  /// from the library since being played) are silently dropped, same as
  /// `StatsService._resolveSongs`.
  Future<List<AuraSongPlayStat>> mostPlayedSongs(AuraTimeWindow window, {int limit = 5}) async {
    final stats = await mostPlayed(window, limit: limit);
    final resolved = <AuraSongPlayStat>[];
    for (final stat in stats) {
      final song = await _songDao.getById(stat.songId);
      if (song != null) resolved.add(AuraSongPlayStat(song: song, playCount: stat.playCount));
    }
    return resolved;
  }

  Stream<List<AuraSongPlayStat>> watchMostPlayedSongs(AuraTimeWindow window, {int limit = 5}) {
    return watchQuery({'play_history', 'songs'}, () => mostPlayedSongs(window, limit: limit));
  }
}
