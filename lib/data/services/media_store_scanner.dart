import 'package:flutter/services.dart';

/// One audio file as reported by Android's MediaStore.
class MediaStoreAudioFile {
  const MediaStoreAudioFile({required this.path, required this.dateAdded});

  final String path;
  final DateTime dateAdded;
}

/// Thin wrapper around the native Android MediaStore query platform
/// channel (`MediaStoreScanner.kt`). Android-only — callers must guard
/// with `Platform.isAndroid`.
///
/// Deliberately returns only path + date-added: MediaStore is used for
/// *discovery* only, so [LibraryScanner] can re-read full tags per file
/// via `audiotags` exactly as it already does on Windows, keeping every
/// downstream step (voice-memo heuristics, cover art, DB upsert) platform-
/// agnostic. See CLAUDE.md's Phase 2.1 decision for why MediaStore replaces
/// the folder-picker-only scan on Android: SAF-resolved folders can't reach
/// many real-world locations (WhatsApp Audio, Downloads, other apps' music
/// folders) the way MediaStore + READ_MEDIA_AUDIO can.
class MediaStoreScanner {
  static const _channel = MethodChannel('com.tamusic.app.ta_music/media_store');

  static Future<List<MediaStoreAudioFile>> queryAudioFiles() async {
    final result = await _channel.invokeMethod<List<Object?>>('queryAudioFiles');
    if (result == null) return [];
    return [
      for (final entry in result)
        if (entry != null) _fromChannelMap(Map<Object?, Object?>.from(entry as Map)),
    ];
  }

  static MediaStoreAudioFile _fromChannelMap(Map<Object?, Object?> map) {
    final path = map['path'] as String;
    final dateAddedSeconds = map['dateAdded'] as int;
    return MediaStoreAudioFile(
      path: path,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(dateAddedSeconds * 1000),
    );
  }
}
