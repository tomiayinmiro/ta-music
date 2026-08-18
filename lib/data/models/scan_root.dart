import 'package:flutter/foundation.dart';

/// A folder the library scanner should walk, mapped 1:1 to a row in the
/// `scan_roots` table.
///
/// Hand-written rather than `freezed` — see `song.dart` for why.
@immutable
class ScanRoot {
  const ScanRoot({this.id, required this.path, required this.addedAt});

  final int? id;
  final String path;
  final DateTime addedAt;

  factory ScanRoot.fromMap(Map<String, Object?> map) {
    return ScanRoot(
      id: map['id'] as int?,
      path: map['path'] as String,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{'path': path, 'added_at': addedAt.millisecondsSinceEpoch};
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  ScanRoot copyWith({int? id, String? path, DateTime? addedAt}) {
    return ScanRoot(
      id: id ?? this.id,
      path: path ?? this.path,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanRoot &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          path == other.path &&
          addedAt == other.addedAt;

  @override
  int get hashCode => Object.hash(id, path, addedAt);

  @override
  String toString() => 'ScanRoot(id: $id, path: $path)';
}
