import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'core/theme/theme_data.dart';
import 'data/providers/repository_providers.dart';
import 'data/providers/theme_providers.dart';
import 'data/providers/update_providers.dart';
import 'features/library/widgets/app_shell.dart';
import 'features/update/widgets/update_dialog.dart';

final _log = Logger();

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final _navigatorKey = GlobalKey<NavigatorState>();

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
    _checkForUpdates();
  }

  // Silent on-launch update check — never awaited by build(), never blocks
  // startup. Any failure (network, malformed manifest) already resolves to
  // "nothing to show" inside UpdateRepository, so there's nothing to catch
  // here beyond a defensive log if something upstream still throws.
  Future<void> _checkForUpdates() async {
    try {
      final packageInfo = await ref.read(packageInfoProvider.future);
      final repo = await ref.read(updateRepositoryProvider.future);
      final outcome = await repo.checkOnLaunch(
        packageInfo: packageInfo,
        isAndroid: Platform.isAndroid,
        isWindows: Platform.isWindows,
      );
      if (outcome == null) return;

      final context = _navigatorKey.currentState?.context;
      if (context == null || !context.mounted) return;
      await UpdateDialog.show(
        context,
        manifest: outcome.manifest,
        installedVersion: outcome.installedVersion,
        mandatory: outcome.mandatory,
        onLater: () => repo.dismiss(outcome.manifest.latestVersion),
      );
    } catch (e, stack) {
      _log.w('[update_check] on-launch check failed unexpectedly', error: e, stackTrace: stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'TA MUSIC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const AppShell(),
    );
  }
}
