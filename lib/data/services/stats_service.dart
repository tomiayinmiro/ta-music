import '../database/daos/listening_segment_dao.dart';
import '../database/daos/play_history_dao.dart';
import '../database/daos/song_dao.dart';
import '../models/song.dart';
import '../repositories/reactive_query.dart';

/// One local artist's play count. No account association — see
/// CLAUDE.md's "Listening stats ... LOCAL ONLY, no accounts".
class TopArtistStat {
  const TopArtistStat({required this.name, required this.playCount});

  final String name;
  final int playCount;
}

class ListeningStats {
  const ListeningStats({
    required this.totalSongsPlayed,
    required this.totalListened,
    required this.topArtists,
    required this.topSongs,
    required this.mostPlayedThisWeek,
  });

  final int totalSongsPlayed;
  final Duration totalListened;
  final List<TopArtistStat> topArtists;
  final List<Song> topSongs;
  final List<Song> mostPlayedThisWeek;

  static const empty = ListeningStats(
    totalSongsPlayed: 0,
    totalListened: Duration.zero,
    topArtists: [],
    topSongs: [],
    mostPlayedThisWeek: [],
  );
}

/// Computes local-only listening stats from `play_history`, surfaced in the
/// nav drawer per CLAUDE.md. Never associates data with any account —
/// there isn't one.
class StatsService {
  StatsService({
    required this._playHistoryDao,
    required this._songDao,
    required this._listeningSegmentDao,
  });

  final PlayHistoryDao _playHistoryDao;
  final SongDao _songDao;
  final ListeningSegmentDao _listeningSegmentDao;

  Stream<ListeningStats> watch() =>
      watchQuery({'play_history', 'songs', 'listening_segments'}, compute);

  /// "Hours listened" is sourced from `listening_segments` (real,
  /// wall-clock-measured time) rather than `play_history`'s full track
  /// durations — same underlying fix as the Aura page's total minutes, see
  /// `_migrationV6`'s doc. `totalPlays == 0` is no longer sufficient on its
  /// own to short-circuit to empty: a listen that never crosses the
  /// 50%-play-count threshold (a quick skip-through) still has real
  /// listened time credited here even with zero counted plays.
  Future<ListeningStats> compute() async {
    final totalPlays = await _playHistoryDao.totalPlayCount();
    final totalMs = await _listeningSegmentDao.totalListenedMs();
    if (totalPlays == 0 && totalMs == 0) return ListeningStats.empty;

    final topArtistPairs = await _playHistoryDao.topArtists(limit: 5);
    final topSongPairs = await _playHistoryDao.topSongIds(limit: 5);
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final thisWeekPairs = await _playHistoryDao.topSongIds(limit: 5, since: weekAgo);

    return ListeningStats(
      totalSongsPlayed: totalPlays,
      totalListened: Duration(milliseconds: totalMs),
      topArtists: [
        for (final (name, plays) in topArtistPairs) TopArtistStat(name: name, playCount: plays),
      ],
      topSongs: await _resolveSongs(topSongPairs),
      mostPlayedThisWeek: await _resolveSongs(thisWeekPairs),
    );
  }

  Future<List<Song>> _resolveSongs(List<(int, int)> songIdAndCount) async {
    final songs = <Song>[];
    for (final (songId, _) in songIdAndCount) {
      final song = await _songDao.getById(songId);
      if (song != null) songs.add(song);
    }
    return songs;
  }
}
