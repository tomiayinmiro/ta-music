// ignore_for_file: avoid_print
//
// One-time tool: downsizes the source fallback-cover images in
// `fallback_covers/` and writes optimized JPGs into `assets/fallback_covers/`
// (general pool) and `assets/fallback_covers/bible/` (the Audio Bible
// special case). Run with `dart run tool/optimize_fallback_covers.dart`.
//
// Source images stay untouched in `fallback_covers/` — only the optimized
// output is meant to be committed/bundled.
import 'dart:io';

import 'package:image/image.dart' as img;

const _maxBytes = 500 * 1024;
const _sourceDir = 'fallback_covers';
const _generalOutDir = 'assets/fallback_covers';
const _bibleOutDir = 'assets/fallback_covers/bible';
const _bibleSourceName = 'AUDIO BIBLE.png';

/// Encode attempts tried in order until the result fits under [_maxBytes].
/// (maxDimension, quality) pairs, loosest first.
const _attempts = [
  (1024, 85),
  (1024, 75),
  (800, 75),
  (800, 65),
  (640, 65),
  (640, 55),
];

void main() {
  final sourceDir = Directory(_sourceDir);
  if (!sourceDir.existsSync()) {
    stderr.writeln('Source directory not found: $_sourceDir');
    exitCode = 1;
    return;
  }

  Directory(_generalOutDir).createSync(recursive: true);
  Directory(_bibleOutDir).createSync(recursive: true);

  final entries = sourceDir
      .listSync()
      .whereType<File>()
      .where((f) => !f.path.endsWith('.gitkeep'))
      .toList();

  final bibleFile = entries.firstWhere(
    (f) => f.uri.pathSegments.last == _bibleSourceName,
    orElse: () => throw StateError('Expected to find $_bibleSourceName in $_sourceDir'),
  );
  final generalFiles = entries.where((f) => f != bibleFile).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (generalFiles.length != 20) {
    stderr.writeln(
      'Expected exactly 20 general fallback images, found ${generalFiles.length}. Aborting.',
    );
    exitCode = 1;
    return;
  }

  var totalOriginal = 0;
  var totalOptimized = 0;
  final rows = <String>[];

  for (var i = 0; i < generalFiles.length; i++) {
    final source = generalFiles[i];
    final outName = 'fallback_${i.toString().padLeft(2, '0')}.jpg';
    final outPath = '$_generalOutDir/$outName';
    final result = _optimize(source, outPath);
    totalOriginal += result.originalBytes;
    totalOptimized += result.optimizedBytes;
    rows.add(
      '${source.uri.pathSegments.last.padRight(45)} -> $outName  '
      '${_fmtKb(result.originalBytes).padLeft(9)} -> ${_fmtKb(result.optimizedBytes).padLeft(8)}  '
      '(${result.width}x${result.height}, q${result.quality})',
    );
  }

  final bibleResult = _optimize(bibleFile, '$_bibleOutDir/audio_bible.jpg');
  totalOriginal += bibleResult.originalBytes;
  totalOptimized += bibleResult.optimizedBytes;
  rows.add(
    '${bibleFile.uri.pathSegments.last.padRight(45)} -> bible/audio_bible.jpg  '
    '${_fmtKb(bibleResult.originalBytes).padLeft(9)} -> ${_fmtKb(bibleResult.optimizedBytes).padLeft(8)}  '
    '(${bibleResult.width}x${bibleResult.height}, q${bibleResult.quality})',
  );

  print('');
  for (final row in rows) {
    print(row);
  }
  print('');
  print('Original: ${_fmtMb(totalOriginal)} total. Optimized: ${_fmtMb(totalOptimized)} total. '
      '${generalFiles.length + 1} files.');
}

class _OptimizeResult {
  _OptimizeResult(this.originalBytes, this.optimizedBytes, this.width, this.height, this.quality);
  final int originalBytes;
  final int optimizedBytes;
  final int width;
  final int height;
  final int quality;
}

_OptimizeResult _optimize(File source, String outPath) {
  final sourceBytes = source.readAsBytesSync();
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    throw StateError('Could not decode ${source.path}');
  }

  List<int>? best;
  var bestQuality = 0;
  var bestWidth = decoded.width;
  var bestHeight = decoded.height;

  for (final (maxDimension, quality) in _attempts) {
    img.Image working = decoded;
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      working = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxDimension)
          : img.copyResize(decoded, height: maxDimension);
    }
    final encoded = img.encodeJpg(working, quality: quality);
    best = encoded;
    bestQuality = quality;
    bestWidth = working.width;
    bestHeight = working.height;
    if (encoded.length <= _maxBytes) break;
  }

  File(outPath).writeAsBytesSync(best!);
  return _OptimizeResult(sourceBytes.length, best.length, bestWidth, bestHeight, bestQuality);
}

String _fmtKb(int bytes) => '${(bytes / 1024).toStringAsFixed(0)}KB';
String _fmtMb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
