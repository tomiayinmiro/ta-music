import 'package:flutter/foundation.dart';

/// An artist, mapped 1:1 to a row in the `artists` table.
///
/// Hand-written rather than `freezed` — see `song.dart` for why.
@immutable
class Artist {
  const Artist({this.id, this.name});

  final int? id;
  final String? name;

  String get displayName => (name != null && name!.trim().isNotEmpty) ? name! : 'Unknown Artist';

  factory Artist.fromMap(Map<String, Object?> map) {
    return Artist(id: map['id'] as int?, name: map['name'] as String?);
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{'name': name};
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  Artist copyWith({int? id, String? name}) {
    return Artist(id: id ?? this.id, name: name ?? this.name);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Artist && runtimeType == other.runtimeType && id == other.id && name == other.name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Artist(id: $id, name: $name)';
}
