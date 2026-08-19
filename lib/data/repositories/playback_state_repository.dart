import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../database/daos/playback_state_dao.dart';
import '../services/playback/playback_models.dart';

/// A persisted playback session, as saved to the `playback_state` table.
@immutable
class PersistedPlaybackState {
  const PersistedPlaybackState({
    required this.currentSongId,
    required this.positionMs,
    required this.queueSongIds,
    required this.currentIndex,
    required this.shuffleEnabled,
    required this.repeatMode,
  });

  final int? currentSongId;
  final int positionMs;
  final List<int> queueSongIds;
  final int? currentIndex;
  final bool shuffleEnabled;
  final PlayerRepeatMode repeatMode;
}

/// Persists/restores the playback session (queue, position, index,
/// shuffle/repeat) across app restarts — bug 3 from the Phase 3 device
/// testing pass. A single row, always upserted, never accumulated history
/// (that's what `play_history` is for).
class PlaybackStateRepository {
  PlaybackStateRepository(this._dao);

  final PlaybackStateDao _dao;

  Future<void> save(PersistedPlaybackState state) {
    return _dao.save({
      'current_song_id': state.currentSongId,
      'position_ms': state.positionMs,
      'queue_song_ids': jsonEncode(state.queueSongIds),
      'current_index': state.currentIndex,
      'shuffle_mode': state.shuffleEnabled ? 1 : 0,
      'repeat_mode': state.repeatMode.name,
      'last_saved_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<PersistedPlaybackState?> load() async {
    final row = await _dao.load();
    if (row == null) return null;
    final queueJson = row['queue_song_ids'] as String? ?? '[]';
    final queueSongIds = (jsonDecode(queueJson) as List).cast<int>();
    return PersistedPlaybackState(
      currentSongId: row['current_song_id'] as int?,
      positionMs: row['position_ms'] as int? ?? 0,
      queueSongIds: queueSongIds,
      currentIndex: row['current_index'] as int?,
      shuffleEnabled: (row['shuffle_mode'] as int? ?? 0) != 0,
      repeatMode: PlayerRepeatMode.values.firstWhere(
        (m) => m.name == row['repeat_mode'],
        orElse: () => PlayerRepeatMode.off,
      ),
    );
  }

  Future<void> clear() => _dao.clear();
}
