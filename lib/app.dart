import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'core/theme/theme_data.dart';
import 'data/providers/library_providers.dart';
import 'data/providers/repository_providers.dart';
import 'data/providers/update_providers.dart';
import 'features/library/widgets/app_shell.dart';
import 'features/update/widgets/update_dialog.dart';

final _log = Logger();

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Seeds a default Windows scan root (the user's Music folder) on first
    // run so there's something to scan without a folder picker up front.
    // No-op on Android and no-op past the first run — see
    // LibraryRepository.ensureDefaultScanRoot.
    Future.microtask(() async {
      final repo = await ref.read(libraryRepositoryProvider.future);
      await repo.ensureDefaultScanRoot();
    });
    // On-launch permission check (2026-09-09 permission-logic fix) — drives
    // both the persistent PermissionBanner and HomeScreen's first-launch
    // rationale flow via the single androidPermissionStatusProvider. No-op
    // off Android.
    if (Platform.isAndroid) {
      Future.microtask(() => ref.read(androidPermissionStatusProvider.notifier).refresh());
    }
    _checkForUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-checks permission whenever the app comes back to the foreground —
  // covers the user granting it from the system Settings page (which this
  // app opens itself, see PermissionBanner/openAppSettings) and switching
  // straight back, without needing to manually tap "Rescan library".
  // AndroidPermissionController.refresh auto-starts a scan if this finds
  // the permission newly granted since the last known status.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      ref.read(androidPermissionStatusProvider.notifier).refresh();
    }
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
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'TA MUSIC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
