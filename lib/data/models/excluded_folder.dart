import 'package:flutter/foundation.dart';

/// A folder the scanner should skip, mapped 1:1 to a row in the
/// `excluded_folders` table. User-configurable, per CLAUDE.md's
/// voice-recording exclusion rule (c).
///
/// Hand-written rather than `freezed` — see `song.dart` for why.
@immutable
class ExcludedFolder {
  const ExcludedFolder({this.id, required this.path});

  final int? id;
  final String path;

  factory ExcludedFolder.fromMap(Map<String, Object?> map) {
    return ExcludedFolder(id: map['id'] as int?, path: map['path'] as String);
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{'path': path};
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  ExcludedFolder copyWith({int? id, String? path}) {
    return ExcludedFolder(id: id ?? this.id, path: path ?? this.path);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExcludedFolder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          path == other.path;

  @override
  int get hashCode => Object.hash(id, path);

  @override
  String toString() => 'ExcludedFolder(id: $id, path: $path)';
}
