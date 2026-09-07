import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The cosmetic icon a user picks when saving a custom EQ preset — purely a
/// visual tag (`designs/custom_eq_presets/`'s icon picker), not tied to any
/// real audio-output-device detection.
enum EqPresetIcon {
  graphicEq('graphic_eq'),
  headphones('headphones'),
  speaker('speaker');

  const EqPresetIcon(this.dbValue);

  final String dbValue;

  static EqPresetIcon fromDbValue(String value) =>
      EqPresetIcon.values.firstWhere((e) => e.dbValue == value, orElse: () => EqPresetIcon.graphicEq);
}

/// A user-saved custom EQ preset, mapped 1:1 to a row in the
/// `custom_eq_presets` table. [bandGains] is a snapshot of every band's gain
/// (in decibels) on the device that saved it, in device band-index order —
/// see `distributeBuiltInPreset`'s doc for why band count isn't fixed.
///
/// Hand-written rather than `freezed` — see `song.dart` for why.
@immutable
class EqPreset {
  const EqPreset({
    this.id,
    required this.name,
    required this.icon,
    required this.bandGains,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final EqPresetIcon icon;
  final List<double> bandGains;
  final DateTime createdAt;

  factory EqPreset.fromMap(Map<String, Object?> map) {
    final decoded = jsonDecode(map['bands_json'] as String) as List<dynamic>;
    return EqPreset(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: EqPresetIcon.fromDbValue(map['icon'] as String),
      bandGains: decoded.map((e) => (e as num).toDouble()).toList(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'name': name,
      'icon': icon.dbValue,
      'bands_json': jsonEncode(bandGains),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  EqPreset copyWith({int? id, String? name, EqPresetIcon? icon, List<double>? bandGains, DateTime? createdAt}) {
    return EqPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      bandGains: bandGains ?? this.bandGains,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EqPreset &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          icon == other.icon &&
          listEquals(bandGains, other.bandGains) &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, name, icon, Object.hashAll(bandGains), createdAt);

  @override
  String toString() => 'EqPreset(id: $id, name: $name)';
}
