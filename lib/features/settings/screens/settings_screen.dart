import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/repository_providers.dart';

/// Minimal folder-management settings, built plainly from sonic_sanctuary_2
/// tokens (no Stitch design — the full Settings screen is Phase 7 and
/// explicitly "ask before building" in DESIGN_MAP). This exists now only
/// because the scanner needs somewhere to be configured; expect it to be
/// reorganized into the real Settings screen later.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanRootsAsync = ref.watch(scanRootsProvider);
    final excludedAsync = ref.watch(excludedFoldersProvider);
    final scanState = ref.watch(libraryScanControllerProvider);
    final isScanning = scanState != null && !scanState.isDone && scanState.error == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          Text('Scan folders', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.stackSm),
          scanRootsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (roots) => Column(
              children: [
                for (final root in roots)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_rounded),
                    title: Text(root.path, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      onPressed: () async {
                        final repo = await ref.read(libraryRepositoryProvider.future);
                        await repo.removeScanRoot(root.id!);
                      },
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add folder'),
                    onPressed: () async {
                      final path = await FilePicker.getDirectoryPath();
                      if (path == null) return;
                      final repo = await ref.read(libraryRepositoryProvider.future);
                      await repo.addScanRoot(path);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          Text('Excluded folders', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.stackSm),
          excludedAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (excluded) => Column(
              children: [
                for (final folder in excluded)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_off_outlined),
                    title: Text(folder.path, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      onPressed: () async {
                        final repo = await ref.read(libraryRepositoryProvider.future);
                        await repo.removeExcludedFolder(folder.id!);
                      },
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Exclude a folder'),
                    onPressed: () async {
                      final path = await FilePicker.getDirectoryPath();
                      if (path == null) return;
                      final repo = await ref.read(libraryRepositoryProvider.future);
                      await repo.addExcludedFolder(path);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          FilledButton.icon(
            onPressed: isScanning
                ? null
                : () => ref.read(libraryScanControllerProvider.notifier).startScan(),
            icon: isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(isScanning ? 'Scanning…' : 'Rescan library'),
          ),
        ],
      ),
    );
  }
}
