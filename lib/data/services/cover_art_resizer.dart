import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Decodes [sourceBytes] and re-encodes as JPEG bounded to [maxDimension] on
/// its longest side, preserving aspect ratio.
///
/// Cover art embedded in audio files (or a `cover.jpg`/`folder.jpg` sitting
/// next to one) can be several thousand pixels per side. That file becomes
/// `covers/{album_id}.jpg` (`_ensureCoverArt` in `library_scanner.dart`) and
/// is handed unresized to `MediaItem.artUri` for the Android media
/// notification/lock screen — a path that bypasses Flutter's own
/// `cacheWidth`/`cacheHeight`-bounded image cache entirely, since it's
/// decoded natively by the OS. A device capture measured this driving
/// native heap usage to 190-350MB during ordinary playback (see CLAUDE.md,
/// manual-lyrics-editor investigation, 2026-09-01) — Android Bitmap pixel
/// data has lived in native heap since API 26, so an oversized decode there
/// never shows up in the Dart/Dalvik heap at all.
///
/// Returns [sourceBytes] unchanged (no re-encode, no quality loss) if
/// already within [maxDimension] on its longest side. Returns [sourceBytes]
/// unchanged if it can't be decoded as an image at all, rather than
/// throwing — one malformed embedded picture shouldn't abort an entire
/// library scan pass.
Uint8List resizeCoverArt(List<int> sourceBytes, {int maxDimension = 1024, int quality = 85}) {
  final bytes = Uint8List.fromList(sourceBytes);
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // Malformed/truncated input can make a format decoder throw (e.g. too
    // short to hold the header it's sniffing for) rather than returning
    // null — caught here so the "never throws" contract above actually
    // holds regardless of which decoder that happens in.
    return bytes;
  }
  if (decoded == null) return bytes;
  if (decoded.width <= maxDimension && decoded.height <= maxDimension) return bytes;

  final resized = decoded.width >= decoded.height
      ? img.copyResize(decoded, width: maxDimension)
      : img.copyResize(decoded, height: maxDimension);
  return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
}
