import 'package:flutter/foundation.dart';

/// An album, mapped 1:1 to a row in the `albums` table.
///
/// Hand-written rather than `freezed` — see `song.dart` for why.
@immutable
class Album {
  const Album({this.id, this.name, this.artist, this.year, this.coverArtPath});

  final int? id;
  final String? name;
  final String? artist;
  final int? year;
  final String? coverArtPath;

  String get displayName => (name != null && name!.trim().isNotEmpty) ? name! : 'Unknown Album';

  factory Album.fromMap(Map<String, Object?> map) {
    return Album(
      id: map['id'] as int?,
      name: map['name'] as String?,
      artist: map['artist'] as String?,
      year: map['year'] as int?,
      coverArtPath: map['cover_art_path'] as String?,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'name': name,
      'artist': artist,
      'year': year,
      'cover_art_path': coverArtPath,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  Album copyWith({int? id, String? name, String? artist, int? year, String? coverArtPath}) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      artist: artist ?? this.artist,
      year: year ?? this.year,
      coverArtPath: coverArtPath ?? this.coverArtPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Album &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          artist == other.artist &&
          year == other.year &&
          coverArtPath == other.coverArtPath;

  @override
  int get hashCode => Object.hash(id, name, artist, year, coverArtPath);

  @override
  String toString() => 'Album(id: $id, name: $name)';
}
