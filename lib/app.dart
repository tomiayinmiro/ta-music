import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/theme_data.dart';
import 'data/providers/repository_providers.dart';
import 'features/library/widgets/app_shell.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    // Seeds a default Windows scan root (the user's Music folder) on first
    // run so there's something to scan without a folder picker up front.
    // No-op on Android and no-op past the first run — see
    // LibraryRepository.ensureDefaultScanRoot.
    Future.microtask(() async {
      final repo = await ref.read(libraryRepositoryProvider.future);
      await repo.ensureDefaultScanRoot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TA MUSIC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
