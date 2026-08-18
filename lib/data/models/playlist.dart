import 'package:flutter/foundation.dart';

/// A user-created playlist, mapped 1:1 to a row in the `playlists` table.
///
/// Hand-written rather than `freezed` — see `song.dart` for why.
@immutable
class Playlist {
  const Playlist({
    this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.coverArtPath,
  });

  final int? id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? coverArtPath;

  factory Playlist.fromMap(Map<String, Object?> map) {
    return Playlist(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      coverArtPath: map['cover_art_path'] as String?,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'name': name,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'cover_art_path': coverArtPath,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  Playlist copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? coverArtPath,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverArtPath: coverArtPath ?? this.coverArtPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          coverArtPath == other.coverArtPath;

  @override
  int get hashCode => Object.hash(id, name, description, createdAt, updatedAt, coverArtPath);

  @override
  String toString() => 'Playlist(id: $id, name: $name)';
}
