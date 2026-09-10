import 'package:flutter/foundation.dart';

/// Current backup file schema version. Bump whenever [BackupPayload]'s JSON
/// shape changes in a way older code can't read, and extend
/// [BackupPayload.fromJson]'s version check accordingly — never change what
/// an already-shipped version number means.
const int kBackupFormatVersion = 1;

/// Thrown for anything that stops an export/import outright: unreadable
/// JSON, a missing/out-of-range `backup_format_version`, or a backup with no
/// data in it at all. Per-item problems (one malformed playlist entry, one
/// song that doesn't resolve locally) are NOT reported this way — those are
/// collected as skip counts/log lines instead, so one bad entry can't sink
/// an otherwise-good backup. See CLAUDE.md's "errors surface as typed
/// exceptions" principle.
class BackupFormatException implements Exception {
  BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Identifies a song across devices/platforms without relying on a stable
/// id — `songs.id` is assigned per-database and a song's absolute `path`
/// never matches between, say, a Windows export and an Android import. See
/// `SongMatchIndex`, which resolves this back to a local [Song].
@immutable
class BackupSongRef {
  const BackupSongRef({required this.path, this.title, this.artist, this.album, this.durationMs});

  final String path;
  final String? title;
  final String? artist;
  final String? album;
  final int? durationMs;

  factory BackupSongRef.fromJson(Map<String, Object?> json) {
    final path = json['path'];
    if (path is! String || path.isEmpty) {
      throw const FormatException('song reference missing path');
    }
    return BackupSongRef(
      path: path,
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      durationMs: json['duration_ms'] as int?,
    );
  }

  Map<String, Object?> toJson() => {
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'duration_ms': durationMs,
  };
}

@immutable
class BackupPlaylistSong {
  const BackupPlaylistSong({required this.song, required this.position, required this.addedAtMs});

  final BackupSongRef song;
  final int position;
  final int addedAtMs;

  factory BackupPlaylistSong.fromJson(Map<String, Object?> json) {
    return BackupPlaylistSong(
      song: BackupSongRef.fromJson(json['song'] as Map<String, Object?>),
      position: json['position'] as int? ?? 0,
      addedAtMs: json['added_at_ms'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
    'song': song.toJson(),
    'position': position,
    'added_at_ms': addedAtMs,
  };
}

@immutable
class BackupPlaylist {
  const BackupPlaylist({
    required this.name,
    this.description,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.songs,
  });

  final String name;
  final String? description;
  final int createdAtMs;
  final int updatedAtMs;
  final List<BackupPlaylistSong> songs;

  factory BackupPlaylist.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('playlist missing name');
    }
    return BackupPlaylist(
      name: name,
      description: json['description'] as String?,
      createdAtMs: json['created_at_ms'] as int? ?? 0,
      updatedAtMs: json['updated_at_ms'] as int? ?? 0,
      songs: _parseList(json['songs'], BackupPlaylistSong.fromJson),
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'created_at_ms': createdAtMs,
    'updated_at_ms': updatedAtMs,
    'songs': [for (final s in songs) s.toJson()],
  };
}

@immutable
class BackupFavorite {
  const BackupFavorite({required this.song, required this.addedAtMs, required this.isManual});

  final BackupSongRef song;
  final int addedAtMs;
  final bool isManual;

  factory BackupFavorite.fromJson(Map<String, Object?> json) {
    return BackupFavorite(
      song: BackupSongRef.fromJson(json['song'] as Map<String, Object?>),
      addedAtMs: json['added_at_ms'] as int? ?? 0,
      isManual: json['is_manual'] as bool? ?? true,
    );
  }

  Map<String, Object?> toJson() => {
    'song': song.toJson(),
    'added_at_ms': addedAtMs,
    'is_manual': isManual,
  };
}

@immutable
class BackupPlayHistoryEntry {
  const BackupPlayHistoryEntry({required this.song, required this.playedAtMs, required this.completed});

  final BackupSongRef song;
  final int playedAtMs;
  final bool completed;

  factory BackupPlayHistoryEntry.fromJson(Map<String, Object?> json) {
    return BackupPlayHistoryEntry(
      song: BackupSongRef.fromJson(json['song'] as Map<String, Object?>),
      playedAtMs: json['played_at_ms'] as int? ?? 0,
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'song': song.toJson(),
    'played_at_ms': playedAtMs,
    'completed': completed,
  };
}

@immutable
class BackupAuraState {
  const BackupAuraState({
    required this.totalListeningMinsCached,
    required this.currentLevel,
    required this.lastShownLevel,
  });

  final int totalListeningMinsCached;
  final int currentLevel;
  final int lastShownLevel;

  static const empty = BackupAuraState(
    totalListeningMinsCached: 0,
    currentLevel: 1,
    lastShownLevel: 0,
  );

  factory BackupAuraState.fromJson(Map<String, Object?> json) {
    return BackupAuraState(
      totalListeningMinsCached: json['total_listening_mins_cached'] as int? ?? 0,
      currentLevel: json['current_level'] as int? ?? 1,
      lastShownLevel: json['last_shown_level'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
    'total_listening_mins_cached': totalListeningMinsCached,
    'current_level': currentLevel,
    'last_shown_level': lastShownLevel,
  };
}

@immutable
class BackupRecommendationSeed {
  const BackupRecommendationSeed({required this.song, required this.selectedAtMs, required this.expiresAtMs});

  final BackupSongRef song;
  final int selectedAtMs;
  final int expiresAtMs;

  factory BackupRecommendationSeed.fromJson(Map<String, Object?> json) {
    return BackupRecommendationSeed(
      song: BackupSongRef.fromJson(json['song'] as Map<String, Object?>),
      selectedAtMs: json['selected_at_ms'] as int? ?? 0,
      expiresAtMs: json['expires_at_ms'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
    'song': song.toJson(),
    'selected_at_ms': selectedAtMs,
    'expires_at_ms': expiresAtMs,
  };
}

/// A manually-added lyrics entry (`lyrics_cache` rows with
/// `source = 'user_added'`) — the only lyrics category the brief exports,
/// since everything else is re-fetchable cache.
@immutable
class BackupManualLyric {
  const BackupManualLyric({
    required this.artistKey,
    required this.titleKey,
    this.displayArtist,
    this.displayTitle,
    required this.hasSyncedTiming,
    this.syncedLyricsLrc,
    this.plainLyrics,
    required this.fetchedAtMs,
  });

  final String artistKey;
  final String titleKey;
  final String? displayArtist;
  final String? displayTitle;
  final bool hasSyncedTiming;
  final String? syncedLyricsLrc;
  final String? plainLyrics;
  final int fetchedAtMs;

  factory BackupManualLyric.fromJson(Map<String, Object?> json) {
    final artistKey = json['artist_key'];
    final titleKey = json['title_key'];
    if (artistKey is! String || titleKey is! String) {
      throw const FormatException('manual lyric missing artist_key/title_key');
    }
    return BackupManualLyric(
      artistKey: artistKey,
      titleKey: titleKey,
      displayArtist: json['display_artist'] as String?,
      displayTitle: json['display_title'] as String?,
      hasSyncedTiming: json['has_synced_timing'] as bool? ?? false,
      syncedLyricsLrc: json['synced_lyrics_lrc'] as String?,
      plainLyrics: json['plain_lyrics'] as String?,
      fetchedAtMs: json['fetched_at_ms'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
    'artist_key': artistKey,
    'title_key': titleKey,
    'display_artist': displayArtist,
    'display_title': displayTitle,
    'has_synced_timing': hasSyncedTiming,
    'synced_lyrics_lrc': syncedLyricsLrc,
    'plain_lyrics': plainLyrics,
    'fetched_at_ms': fetchedAtMs,
  };
}

/// The portable subset of `settings` — deliberately NOT everything in the
/// table. Scanned/excluded folders (absolute, device-specific paths) and EQ
/// enabled/gains (Android-only, same reasoning that already excludes EQ
/// presets from export) are left out entirely. See CLAUDE.md's Backup &
/// Restore decisions.
@immutable
class BackupPreferences {
  const BackupPreferences({
    required this.playbackSpeed,
    this.translationTargetLanguage,
    required this.resumeAfterInterruption,
    required this.recommendationsEnabled,
  });

  final double playbackSpeed;
  final String? translationTargetLanguage;
  final bool resumeAfterInterruption;
  final bool recommendationsEnabled;

  factory BackupPreferences.fromJson(Map<String, Object?> json) {
    return BackupPreferences(
      playbackSpeed: (json['playback_speed'] as num?)?.toDouble() ?? 1.0,
      translationTargetLanguage: json['translation_target_language'] as String?,
      resumeAfterInterruption: json['resume_after_interruption'] as bool? ?? false,
      recommendationsEnabled: json['recommendations_enabled'] as bool? ?? true,
    );
  }

  Map<String, Object?> toJson() => {
    'playback_speed': playbackSpeed,
    'translation_target_language': translationTargetLanguage,
    'resume_after_interruption': resumeAfterInterruption,
    'recommendations_enabled': recommendationsEnabled,
  };
}

/// The full contents of one `.json` backup file.
@immutable
class BackupPayload {
  const BackupPayload({
    required this.backupFormatVersion,
    required this.appVersion,
    required this.exportedAtMs,
    required this.playlists,
    required this.favorites,
    required this.playHistory,
    required this.auraState,
    this.recommendationSeed,
    required this.manualLyrics,
    required this.preferences,
    this.parseWarnings = const [],
  });

  final int backupFormatVersion;
  final String appVersion;
  final int exportedAtMs;
  final List<BackupPlaylist> playlists;
  final List<BackupFavorite> favorites;
  final List<BackupPlayHistoryEntry> playHistory;
  final BackupAuraState auraState;
  final BackupRecommendationSeed? recommendationSeed;
  final List<BackupManualLyric> manualLyrics;
  final BackupPreferences preferences;

  /// Individual entries dropped during [fromJson] because they didn't parse
  /// (missing required fields, wrong type) — never populated by callers
  /// building a payload for export, only by [fromJson]. Folded into
  /// `BackupImportService`'s skip count/log so a handful of malformed rows
  /// in an otherwise-valid backup show up as "skipped," not a hard failure.
  final List<String> parseWarnings;

  Map<String, Object?> toJson() {
    final now = DateTime.fromMillisecondsSinceEpoch(exportedAtMs).toUtc();
    return {
      'backup_format_version': backupFormatVersion,
      'app_version': appVersion,
      'exported_at_ms': exportedAtMs,
      'exported_at_iso': now.toIso8601String(),
      'playlists': [for (final p in playlists) p.toJson()],
      'favorites': [for (final f in favorites) f.toJson()],
      'play_history': [for (final h in playHistory) h.toJson()],
      'aura_state': auraState.toJson(),
      'recommendation_seed': recommendationSeed?.toJson(),
      'manual_lyrics': [for (final l in manualLyrics) l.toJson()],
      'preferences': preferences.toJson(),
    };
  }

  /// Parses and validates a decoded backup JSON map, throwing
  /// [BackupFormatException] for anything that makes the whole file
  /// unusable (bad/missing version, no data at all). Individual malformed
  /// entries within an otherwise-valid list are skipped and recorded in
  /// [parseWarnings] rather than failing the whole import — see
  /// `_parseList`.
  factory BackupPayload.fromJson(Map<String, Object?> json) {
    final version = json['backup_format_version'];
    if (version is! int) {
      throw BackupFormatException(
        "This file doesn't look like a TA Music backup — it's missing its format version.",
      );
    }
    if (version < kBackupFormatVersion) {
      throw BackupFormatException(
        'This backup was made with an older TA Music backup format (v$version) that this '
        'version of the app no longer reads.',
      );
    }
    if (version > kBackupFormatVersion) {
      throw BackupFormatException(
        'This backup was made with a newer version of TA Music (backup format v$version). '
        'Update the app before importing it.',
      );
    }

    final warnings = <String>[];

    final playlists = _parseList(
      json['playlists'],
      BackupPlaylist.fromJson,
      onError: (e) => warnings.add('Skipped a playlist entry: $e'),
    );
    final favorites = _parseList(
      json['favorites'],
      BackupFavorite.fromJson,
      onError: (e) => warnings.add('Skipped a favorite entry: $e'),
    );
    final playHistory = _parseList(
      json['play_history'],
      BackupPlayHistoryEntry.fromJson,
      onError: (e) => warnings.add('Skipped a play history entry: $e'),
    );
    final manualLyrics = _parseList(
      json['manual_lyrics'],
      BackupManualLyric.fromJson,
      onError: (e) => warnings.add('Skipped a manual lyrics entry: $e'),
    );

    BackupAuraState auraState = BackupAuraState.empty;
    final auraJson = json['aura_state'];
    if (auraJson is Map<String, Object?>) {
      try {
        auraState = BackupAuraState.fromJson(auraJson);
      } catch (e) {
        warnings.add('Skipped Aura state: $e');
      }
    }

    BackupRecommendationSeed? recommendationSeed;
    final seedJson = json['recommendation_seed'];
    if (seedJson is Map<String, Object?>) {
      try {
        recommendationSeed = BackupRecommendationSeed.fromJson(seedJson);
      } catch (e) {
        warnings.add('Skipped the cached recommendation seed: $e');
      }
    }

    BackupPreferences preferences = const BackupPreferences(
      playbackSpeed: 1.0,
      resumeAfterInterruption: false,
      recommendationsEnabled: true,
    );
    final prefsJson = json['preferences'];
    if (prefsJson is Map<String, Object?>) {
      try {
        preferences = BackupPreferences.fromJson(prefsJson);
      } catch (e) {
        warnings.add('Skipped preferences: $e');
      }
    }

    final hasAnyData =
        playlists.isNotEmpty ||
        favorites.isNotEmpty ||
        playHistory.isNotEmpty ||
        manualLyrics.isNotEmpty ||
        auraState.totalListeningMinsCached > 0;
    if (!hasAnyData) {
      throw BackupFormatException('This backup contains no data.');
    }

    return BackupPayload(
      backupFormatVersion: version,
      appVersion: json['app_version'] as String? ?? 'unknown',
      exportedAtMs: json['exported_at_ms'] as int? ?? 0,
      playlists: playlists,
      favorites: favorites,
      playHistory: playHistory,
      auraState: auraState,
      recommendationSeed: recommendationSeed,
      manualLyrics: manualLyrics,
      preferences: preferences,
      parseWarnings: warnings,
    );
  }
}

/// Maps every element of [raw] (expected to be a `List<dynamic>` of
/// `Map<String, Object?>`, as produced by `jsonDecode`) through [parse],
/// skipping — via [onError] — any element that isn't a map or fails to
/// parse, instead of letting one bad entry fail the whole list. `raw` being
/// missing or the wrong type entirely (not a list at all) degrades to an
/// empty list rather than throwing, per the brief's "missing sections
/// import what's valid."
List<T> _parseList<T>(
  Object? raw,
  T Function(Map<String, Object?>) parse, {
  void Function(Object error)? onError,
}) {
  if (raw is! List) return [];
  final results = <T>[];
  for (final item in raw) {
    if (item is! Map<String, Object?>) {
      onError?.call('not an object');
      continue;
    }
    try {
      results.add(parse(item));
    } catch (e) {
      onError?.call(e);
    }
  }
  return results;
}
