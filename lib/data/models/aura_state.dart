import 'package:flutter/foundation.dart';

/// The single-row `aura_state` cache: total listening minutes, the level
/// derived from them, and the last level shown to the user (for level-up
/// transition detection — see the Aura service/screen in Phase 4.5).
///
/// Hand-written rather than `freezed` — see `song.dart` for why.
@immutable
class AuraState {
  const AuraState({
    required this.totalListeningMinsCached,
    required this.currentLevel,
    required this.lastShownLevel,
    this.lastComputedAt,
  });

  final int totalListeningMinsCached;

  /// 1-based [AuraLevel.number] as of the last [AuraService.recompute] call.
  final int currentLevel;

  /// 1-based level last shown via the level-up transition. 0 means never
  /// shown (a brand-new install).
  final int lastShownLevel;

  final DateTime? lastComputedAt;

  /// Pre-recompute default: no listening yet, Atmosphere, never shown.
  static const initial = AuraState(
    totalListeningMinsCached: 0,
    currentLevel: 1,
    lastShownLevel: 0,
  );

  factory AuraState.fromMap(Map<String, Object?> map) {
    return AuraState(
      totalListeningMinsCached: map['total_listening_mins_cached'] as int? ?? 0,
      currentLevel: map['current_level'] as int? ?? 1,
      lastShownLevel: map['last_shown_level'] as int? ?? 0,
      lastComputedAt: map['last_computed_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['last_computed_at'] as int),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'total_listening_mins_cached': totalListeningMinsCached,
      'current_level': currentLevel,
      'last_shown_level': lastShownLevel,
      'last_computed_at': lastComputedAt?.millisecondsSinceEpoch,
    };
  }

  AuraState copyWith({
    int? totalListeningMinsCached,
    int? currentLevel,
    int? lastShownLevel,
    DateTime? lastComputedAt,
  }) {
    return AuraState(
      totalListeningMinsCached: totalListeningMinsCached ?? this.totalListeningMinsCached,
      currentLevel: currentLevel ?? this.currentLevel,
      lastShownLevel: lastShownLevel ?? this.lastShownLevel,
      lastComputedAt: lastComputedAt ?? this.lastComputedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuraState &&
          runtimeType == other.runtimeType &&
          totalListeningMinsCached == other.totalListeningMinsCached &&
          currentLevel == other.currentLevel &&
          lastShownLevel == other.lastShownLevel &&
          lastComputedAt == other.lastComputedAt;

  @override
  int get hashCode =>
      Object.hash(totalListeningMinsCached, currentLevel, lastShownLevel, lastComputedAt);

  @override
  String toString() =>
      'AuraState(totalListeningMinsCached: $totalListeningMinsCached, '
      'currentLevel: $currentLevel, lastShownLevel: $lastShownLevel)';
}
