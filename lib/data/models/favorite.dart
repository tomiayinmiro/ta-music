import 'package:flutter/foundation.dart';

/// A song's favorite status, mapped 1:1 to a row in the `favorites` table.
///
/// Hand-written rather than `freezed` — see `song.dart` for why.
@immutable
class Favorite {
  const Favorite({required this.songId, required this.addedAt, required this.isManual});

  final int songId;
  final DateTime addedAt;
  final bool isManual;

  factory Favorite.fromMap(Map<String, Object?> map) {
    return Favorite(
      songId: map['song_id'] as int,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
      isManual: (map['is_manual'] as int) != 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'song_id': songId,
      'added_at': addedAt.millisecondsSinceEpoch,
      'is_manual': isManual ? 1 : 0,
    };
  }

  Favorite copyWith({int? songId, DateTime? addedAt, bool? isManual}) {
    return Favorite(
      songId: songId ?? this.songId,
      addedAt: addedAt ?? this.addedAt,
      isManual: isManual ?? this.isManual,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Favorite &&
          runtimeType == other.runtimeType &&
          songId == other.songId &&
          addedAt == other.addedAt &&
          isManual == other.isManual;

  @override
  int get hashCode => Object.hash(songId, addedAt, isManual);

  @override
  String toString() => 'Favorite(songId: $songId)';
}
