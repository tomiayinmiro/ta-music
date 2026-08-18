import 'package:flutter/foundation.dart';

/// A song's membership + position in a playlist, mapped 1:1 to a row in the
/// `playlist_songs` join table.
///
/// Hand-written rather than `freezed` — see `song.dart` for why.
@immutable
class PlaylistSong {
  const PlaylistSong({
    required this.playlistId,
    required this.songId,
    required this.position,
    required this.addedAt,
  });

  final int playlistId;
  final int songId;
  final int position;
  final DateTime addedAt;

  factory PlaylistSong.fromMap(Map<String, Object?> map) {
    return PlaylistSong(
      playlistId: map['playlist_id'] as int,
      songId: map['song_id'] as int,
      position: map['position'] as int,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'playlist_id': playlistId,
      'song_id': songId,
      'position': position,
      'added_at': addedAt.millisecondsSinceEpoch,
    };
  }

  PlaylistSong copyWith({int? playlistId, int? songId, int? position, DateTime? addedAt}) {
    return PlaylistSong(
      playlistId: playlistId ?? this.playlistId,
      songId: songId ?? this.songId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistSong &&
          runtimeType == other.runtimeType &&
          playlistId == other.playlistId &&
          songId == other.songId &&
          position == other.position &&
          addedAt == other.addedAt;

  @override
  int get hashCode => Object.hash(playlistId, songId, position, addedAt);

  @override
  String toString() => 'PlaylistSong(playlistId: $playlistId, songId: $songId)';
}
