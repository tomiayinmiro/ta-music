import 'package:flutter/foundation.dart';

/// A track in the library, mapped 1:1 to a row in the `songs` table.
///
/// Hand-written immutable class rather than `freezed` — the pinned
/// `analyzer` version (capped by freezed 2.5.8, itself capped by
/// audiotags' `freezed_annotation` constraint) can't parse the current
/// Dart SDK's own framework syntax, which breaks `build_runner` entirely.
/// Approved 2026-08-17: hand-write model boilerplate until that's
/// resolved, then migrate back to `@freezed`.
@immutable
class Song {
  const Song({
    this.id,
    required this.path,
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.durationMs,
    this.fileSize,
    this.format,
    this.sampleRate,
    this.bitRate,
    required this.dateAdded,
    this.lastModified,
    this.playCount = 0,
    this.lastPlayedAt,
    this.isExcluded = false,
    this.albumId,
    this.artistId,
    this.isMissing = false,
  });

  final int? id;
  final String path;
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int? durationMs;
  final int? fileSize;
  final String? format;
  final int? sampleRate;
  final int? bitRate;
  final DateTime dateAdded;
  final DateTime? lastModified;
  final int playCount;
  final DateTime? lastPlayedAt;
  final bool isExcluded;
  final int? albumId;
  final int? artistId;
  final bool isMissing;

  /// Display title: falls back to the file name (minus extension) when the
  /// file has no title tag, so nothing in the UI ever shows a blank row.
  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) return title!;
    final fileName = path.split(RegExp(r'[\\/]')).last;
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  }

  String get displayArtist =>
      (artist != null && artist!.trim().isNotEmpty) ? artist! : 'Unknown Artist';

  Duration get duration => Duration(milliseconds: durationMs ?? 0);

  factory Song.fromMap(Map<String, Object?> map) {
    return Song(
      id: map['id'] as int?,
      path: map['path'] as String,
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      albumArtist: map['album_artist'] as String?,
      genre: map['genre'] as String?,
      year: map['year'] as int?,
      trackNumber: map['track_number'] as int?,
      discNumber: map['disc_number'] as int?,
      durationMs: map['duration_ms'] as int?,
      fileSize: map['file_size'] as int?,
      format: map['format'] as String?,
      sampleRate: map['sample_rate'] as int?,
      bitRate: map['bit_rate'] as int?,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(map['date_added'] as int),
      lastModified: map['last_modified'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['last_modified'] as int),
      playCount: map['play_count'] as int? ?? 0,
      lastPlayedAt: map['last_played_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['last_played_at'] as int),
      isExcluded: (map['is_excluded'] as int? ?? 0) != 0,
      albumId: map['album_id'] as int?,
      artistId: map['artist_id'] as int?,
      isMissing: (map['is_missing'] as int? ?? 0) != 0,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'album_artist': albumArtist,
      'genre': genre,
      'year': year,
      'track_number': trackNumber,
      'disc_number': discNumber,
      'duration_ms': durationMs,
      'file_size': fileSize,
      'format': format,
      'sample_rate': sampleRate,
      'bit_rate': bitRate,
      'date_added': dateAdded.millisecondsSinceEpoch,
      'last_modified': lastModified?.millisecondsSinceEpoch,
      'play_count': playCount,
      'last_played_at': lastPlayedAt?.millisecondsSinceEpoch,
      'is_excluded': isExcluded ? 1 : 0,
      'album_id': albumId,
      'artist_id': artistId,
      'is_missing': isMissing ? 1 : 0,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  Song copyWith({
    int? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
    int? durationMs,
    int? fileSize,
    String? format,
    int? sampleRate,
    int? bitRate,
    DateTime? dateAdded,
    DateTime? lastModified,
    int? playCount,
    DateTime? lastPlayedAt,
    bool? isExcluded,
    int? albumId,
    int? artistId,
    bool? isMissing,
  }) {
    return Song(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      durationMs: durationMs ?? this.durationMs,
      fileSize: fileSize ?? this.fileSize,
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      bitRate: bitRate ?? this.bitRate,
      dateAdded: dateAdded ?? this.dateAdded,
      lastModified: lastModified ?? this.lastModified,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      isExcluded: isExcluded ?? this.isExcluded,
      albumId: albumId ?? this.albumId,
      artistId: artistId ?? this.artistId,
      isMissing: isMissing ?? this.isMissing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          path == other.path &&
          title == other.title &&
          artist == other.artist &&
          album == other.album &&
          albumArtist == other.albumArtist &&
          genre == other.genre &&
          year == other.year &&
          trackNumber == other.trackNumber &&
          discNumber == other.discNumber &&
          durationMs == other.durationMs &&
          fileSize == other.fileSize &&
          format == other.format &&
          sampleRate == other.sampleRate &&
          bitRate == other.bitRate &&
          dateAdded == other.dateAdded &&
          lastModified == other.lastModified &&
          playCount == other.playCount &&
          lastPlayedAt == other.lastPlayedAt &&
          isExcluded == other.isExcluded &&
          albumId == other.albumId &&
          artistId == other.artistId &&
          isMissing == other.isMissing;

  @override
  int get hashCode => Object.hash(
        id,
        path,
        title,
        artist,
        album,
        albumArtist,
        genre,
        year,
        Object.hash(trackNumber, discNumber, durationMs, fileSize, format, sampleRate, bitRate),
        Object.hash(dateAdded, lastModified, playCount, lastPlayedAt, isExcluded),
        Object.hash(albumId, artistId, isMissing),
      );

  @override
  String toString() => 'Song(id: $id, path: $path, title: $title)';
}
