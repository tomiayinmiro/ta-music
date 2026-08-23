import 'dart:io';

import 'package:logger/logger.dart';

/// The sidecar `.lrc` path for an audio file — same folder, same base name
/// (e.g. `/Music/Wizkid/Essence.mp3` -> `/Music/Wizkid/Essence.lrc`). Pulled
/// out as a pure function so the path math is unit-testable without
/// touching the filesystem.
String lrcSidecarPathFor(String audioFilePath) {
  final dotIndex = audioFilePath.lastIndexOf('.');
  final slashIndex = audioFilePath.lastIndexOf(RegExp(r'[\\/]'));
  final base = dotIndex > slashIndex ? audioFilePath.substring(0, dotIndex) : audioFilePath;
  return '$base.lrc';
}

/// Reads a local `.lrc` sidecar file next to an audio file — Layer 3 of the
/// lyrics fallback chain, for songs neither LRCLIB nor lyrics.ovh has.
///
/// Best-effort on Android: the app deliberately doesn't request
/// `MANAGE_EXTERNAL_STORAGE` (see `AndroidManifest.xml`) since it only needs
/// `READ_MEDIA_AUDIO` for the audio files themselves, and a `.lrc` text file
/// isn't part of any MediaStore collection that permission covers. On
/// scoped-storage Android this read can throw a permission error — caught
/// here and treated the same as "file not found" rather than surfacing an
/// error, so this layer degrades to a no-op on devices/OS versions where it
/// can't work, instead of blowing up the whole fallback chain. Unrestricted
/// on Windows.
class LocalLrcFileReader {
  LocalLrcFileReader();

  final _logger = Logger();

  Future<String?> read(String audioFilePath) async {
    final lrcPath = lrcSidecarPathFor(audioFilePath);
    try {
      final file = File(lrcPath);
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      _logger.i('[lyrics] local .lrc read failed (treated as a miss) path=$lrcPath error=$e');
      return null;
    }
  }
}
