import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/providers/update_providers.dart';
import '../../../data/repositories/update_repository.dart';
import '../../../data/services/update/installer_detector.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass_container.dart';
import '../widgets/update_dialog.dart';

/// Reached from the nav drawer's "Version" entry (moved out of Settings —
/// see CLAUDE.md's Version/About restructuring decisions). Shows the
/// installed version prominently and hosts the manual "Check for updates"
/// button that used to live in Settings' About section, unchanged in
/// behavior.
class VersionScreen extends ConsumerWidget {
  const VersionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfoAsync = ref.watch(packageInfoProvider);

    return AppScaffold(
      appBar: AppBar(title: const Text('Version')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          packageInfoAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.stackLg),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (packageInfo) => _VersionContent(packageInfo: packageInfo),
          ),
        ],
      ),
    );
  }
}

class _VersionContent extends ConsumerStatefulWidget {
  const _VersionContent({required this.packageInfo});

  final PackageInfo packageInfo;

  @override
  ConsumerState<_VersionContent> createState() => _VersionContentState();
}

class _VersionContentState extends ConsumerState<_VersionContent> {
  bool _checking = false;
  DateTime? _lastCheckedAt;
  bool _lastCheckedLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadLastCheckedAt();
  }

  Future<void> _loadLastCheckedAt() async {
    final repo = await ref.read(settingsRepositoryProvider.future);
    final lastCheckedAt = await repo.getLastUpdateCheckAt();
    if (!mounted) return;
    setState(() {
      _lastCheckedAt = lastCheckedAt;
      _lastCheckedLoaded = true;
    });
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final repo = await ref.read(updateRepositoryProvider.future);
      final outcome = await repo.checkManually(packageInfo: widget.packageInfo);
      if (!mounted) return;

      switch (outcome) {
        case UpdateAvailableOutcome():
          await UpdateDialog.show(
            context,
            manifest: outcome.manifest,
            installedVersion: outcome.installedVersion,
            mandatory: outcome.mandatory,
            onLater: () => repo.dismiss(outcome.manifest.latestVersion),
          );
        case UpToDateOutcome():
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("You're on the latest version.")));
        case UpdateCheckFailedOutcome():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't check for updates. Check your connection.")),
          );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
      await _loadLastCheckedAt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlayStoreInstall = !shouldCheckForUpdates(
      isAndroid: Platform.isAndroid,
      isWindows: Platform.isWindows,
      installerStore: widget.packageInfo.installerStore,
    );

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT VERSION',
            style: AppTypography.overline.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Text(widget.packageInfo.version, style: AppTypography.displayLg),
          const SizedBox(height: AppSpacing.stackLg),
          if (isPlayStoreInstall)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.storefront_outlined, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: Text('Updates are managed by Google Play', style: theme.textTheme.bodyMedium),
                ),
              ],
            )
          else ...[
            Text(
              "Tap 'Check for updates' to see if a new version is available.",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            FilledButton.icon(
              onPressed: _checking ? null : _check,
              icon: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_rounded),
              label: Text(_checking ? 'Checking…' : 'Check for updates'),
            ),
            if (_lastCheckedLoaded) ...[
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                _lastCheckedAt == null
                    ? 'Last checked: never'
                    : 'Last checked: ${_formatCheckedAt(_lastCheckedAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

String _formatCheckedAt(DateTime timestamp) {
  final local = timestamp.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} $hour:$minute $period';
}
