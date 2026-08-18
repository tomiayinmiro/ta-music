import 'package:flutter/foundation.dart';

/// One playback event, mapped 1:1 to a row in the `play_history` table.
/// The source of truth for local listening stats.
///
/// Hand-written rather than `freezed` — see `song.dart` for why.
@immutable
class PlayHistoryEntry {
  const PlayHistoryEntry({
    this.id,
    required this.songId,
    required this.playedAt,
    required this.completed,
  });

  final int? id;
  final int songId;
  final DateTime playedAt;
  final bool completed;

  factory PlayHistoryEntry.fromMap(Map<String, Object?> map) {
    return PlayHistoryEntry(
      id: map['id'] as int?,
      songId: map['song_id'] as int,
      playedAt: DateTime.fromMillisecondsSinceEpoch(map['played_at'] as int),
      completed: (map['completed'] as int) != 0,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'song_id': songId,
      'played_at': playedAt.millisecondsSinceEpoch,
      'completed': completed ? 1 : 0,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  PlayHistoryEntry copyWith({int? id, int? songId, DateTime? playedAt, bool? completed}) {
    return PlayHistoryEntry(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      playedAt: playedAt ?? this.playedAt,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayHistoryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          songId == other.songId &&
          playedAt == other.playedAt &&
          completed == other.completed;

  @override
  int get hashCode => Object.hash(id, songId, playedAt, completed);

  @override
  String toString() => 'PlayHistoryEntry(id: $id, songId: $songId)';
}
