import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repository_providers.dart';

/// Parses `SettingsRepository.watchThemeMode()`'s raw 'light'/'dark'/'system'
/// string into a real [ThemeMode] — kept out of the repository itself so the
/// data layer stays Flutter-free. Unrecognized/missing values fall back to
/// [ThemeMode.system].
final themeModeProvider = StreamProvider<ThemeMode>((ref) async* {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  yield* repo.watchThemeMode().map(
    (raw) => switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
  );
});
