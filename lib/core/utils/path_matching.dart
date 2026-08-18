import 'dart:io';

import 'package:path/path.dart' as p;

/// Normalizes a path for comparison: resolves `.`/`..` segments and
/// lowercases (Windows/most Android filesystems are case-insensitive;
/// comparing lowercased avoids "Music" vs "music" mismatches without
/// affecting the stored, original-case path).
String normalizePathForComparison(String path) => p.normalize(path).toLowerCase();

/// Whether [path] is equal to, or nested under, [root] — boundary-aware, so
/// "MusicOld" is never mistaken for a child of "Music".
bool isPathUnderRoot(String path, String root) {
  final normalizedPath = normalizePathForComparison(path);
  final normalizedRoot = normalizePathForComparison(root);
  return normalizedPath == normalizedRoot ||
      normalizedPath.startsWith('$normalizedRoot${Platform.pathSeparator}');
}

/// Whether [path] is under any of [roots].
bool isPathUnderAnyRoot(String path, Iterable<String> roots) {
  for (final root in roots) {
    if (isPathUnderRoot(path, root)) return true;
  }
  return false;
}
