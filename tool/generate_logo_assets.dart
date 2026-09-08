// One-time generator: derives every launcher/splash/About-screen asset the
// app actually needs from the sphere-only source at
// `logo/TA MUSIC LAUNCHER ICON.jpg` (never modified — the file is a JPEG
// despite its .png-sounding name; decoded directly). This image fills its
// frame edge-to-edge, which is exactly what's wanted for the legacy Android
// icon, the Windows .ico, the pre-Android-12 splash, and the About screen —
// but fed unpadded into an Android *adaptive* icon foreground, the circular
// launcher mask would crop the sphere's rim. So two variants are produced:
// an edge-to-edge one for those first four contexts, and a safe-zone-padded
// one for the adaptive icon foreground + Android 12 splash icon specifically
// (see _writePaddedAdaptiveForeground). Both are also quantized to a
// 256-color palette — verified visually indistinguishable at these sizes —
// which keeps the generated Android resources well under budget; see the
// bundle-size note in CLAUDE.md's logo-integration decisions.
//
// The earlier full "T + play triangle + MUSIC text" logo
// (`logo/TA MUSIC APP LOGO.png`) is intentionally not used here anymore —
// it's kept only for future marketing use (Play Store hero image, README
// banner), not referenced anywhere in the app.
//
// Produces three files under assets/images/logo/:
//   - ta_music_icon_source.png: full-res (1024), quantized, edge-to-edge.
//     Feeds flutter_launcher_icons' legacy `image_path` (Android + Windows)
//     and flutter_native_splash's pre-Android-12 `image`.
//   - ta_music_icon_adaptive_fg.png: full-res, padded so the sphere sits in
//     the ~62% adaptive-icon safe zone, RGB-quantized with the original
//     per-pixel alpha manually reapplied afterward — package:image's
//     quantize() drops alpha entirely, so a plain quantize+recompose would
//     flatten the transparent padding to opaque. Feeds the Android
//     adaptive-icon foreground and the Android 12+ splash icon
//     (`android_12.image`).
//   - ta_music_icon.png: small (480px), quantized. The only one of the
//     three registered as a real Flutter asset (see pubspec.yaml) — used
//     directly by the About screen at ~132 logical px.
//
// Run once via: dart run tool/generate_logo_assets.dart
// Re-run flutter_launcher_icons / flutter_native_splash:create afterward.
import 'dart:io';

import 'package:image/image.dart' as img;

const _sourcePath = 'logo/TA MUSIC LAUNCHER ICON.jpg';
const _outDir = 'assets/images/logo';
const _safeZoneFraction = 0.62;
const _aboutScreenSize = 480;
const _quantizeColors = 256;

void main() {
  final source = img.decodeJpg(File(_sourcePath).readAsBytesSync())!;

  _writeQuantizedOpaque(source, '$_outDir/ta_music_icon_source.png', source.width, source.height);
  _writeQuantizedOpaque(source, '$_outDir/ta_music_icon.png', _aboutScreenSize, _aboutScreenSize);
  _writePaddedAdaptiveForeground(source);
}

void _writeQuantizedOpaque(img.Image source, String outPath, int width, int height) {
  final resized = (width == source.width && height == source.height)
      ? source
      : img.copyResize(source, width: width, height: height, interpolation: img.Interpolation.cubic);
  final quantized = img.quantize(resized, numberOfColors: _quantizeColors);
  final bytes = img.encodePng(quantized, level: 9);
  File(outPath).writeAsBytesSync(bytes);
  stdout.writeln('Wrote $outPath (${quantized.width}x${quantized.height}, ${bytes.length} bytes)');
}

void _writePaddedAdaptiveForeground(img.Image source) {
  final canvasSize = source.width;
  final contentSize = (canvasSize * _safeZoneFraction).round();
  final resized = img.copyResize(
    source,
    width: contentSize,
    height: contentSize,
    interpolation: img.Interpolation.cubic,
  );

  final padded = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  img.fill(padded, color: img.ColorRgba8(0, 0, 0, 0));
  final offset = ((canvasSize - contentSize) / 2).round();
  img.compositeImage(padded, resized, dstX: offset, dstY: offset);

  // quantize() discards alpha (returns an opaque RGB image), so quantize the
  // color channels only, then recompose against the padded image's own
  // per-pixel alpha rather than trusting quantize()'s output alpha.
  final quantizedColor = img.quantize(padded, numberOfColors: _quantizeColors);
  final result = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  for (var y = 0; y < canvasSize; y++) {
    for (var x = 0; x < canvasSize; x++) {
      final color = quantizedColor.getPixel(x, y);
      final alpha = padded.getPixel(x, y).a;
      result.setPixelRgba(x, y, color.r, color.g, color.b, alpha);
    }
  }

  final bytes = img.encodePng(result, level: 9);
  final outPath = '$_outDir/ta_music_icon_adaptive_fg.png';
  File(outPath).writeAsBytesSync(bytes);
  stdout.writeln('Wrote $outPath (${result.width}x${result.height}, ${bytes.length} bytes)');
}
