import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass_container.dart';

/// Settings — "Manage folders" pulled forward from Phase 7 (approved
/// 2026-08-18). No dedicated Stitch design exists for a folder-management
/// settings screen; the glass-card-with-caps-label treatment here is
/// borrowed from the one relevant precedent that does exist —
/// `designs/navigation_drawer_audio_customization`'s "AUDIO ENGINE" drawer
/// panel — since that's the closest thing sonic_sanctuary_2 offers to a
/// settings section pattern. The rest of Settings (theme, cache, about)
/// still isn't built — that's the real Phase 7 scope.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanRootsAsync = ref.watch(scanRootsProvider);
    final excludedAsync = ref.watch(excludedFoldersProvider);
    final scanState = ref.watch(libraryScanControllerProvider);
    final isScanning =
        scanState != null && !scanState.isDone && scanState.error == null;
    final theme = Theme.of(context);

    return AppScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          Text('Manage folders', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            Platform.isAndroid
                ? 'TA MUSIC already sees every audio file on your device by '
                      'default. Add folders here only if you want to narrow that '
                      'down, and exclude folders to skip them even if they\'re '
                      'inside a scanned one.'
                : 'Choose which folders TA MUSIC scans, and which ones to skip '
                      'even if they\'re inside a scanned folder.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.stackMd),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.stackMd),
            child: _FolderSection(
              label: 'SCANNED FOLDERS',
              icon: Icons.folder_rounded,
              emptyMessage: Platform.isAndroid
                  ? 'None added — scanning everything by default.'
                  : 'No folders added yet.',
              addLabel: 'Add folder',
              itemsAsync: scanRootsAsync.whenData(
                (roots) => roots.map((r) => r.path).toList(),
              ),
              onRemove: (path, index) async {
                final roots = scanRootsAsync.value!;
                final repo = await ref.read(libraryRepositoryProvider.future);
                await repo.removeScanRoot(roots[index].id!);
              },
              onAdd: () => _addScanFolder(context, ref),
            ),
          ),
          const SizedBox(height: AppSpacing.stackMd),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.stackMd),
            child: _FolderSection(
              label: 'EXCLUDED FOLDERS',
              icon: Icons.folder_off_outlined,
              emptyMessage: 'Nothing excluded.',
              addLabel: 'Exclude a folder',
              itemsAsync: excludedAsync.whenData(
                (folders) => folders.map((f) => f.path).toList(),
              ),
              onRemove: (path, index) async {
                final folders = excludedAsync.value!;
                final repo = await ref.read(libraryRepositoryProvider.future);
                await repo.removeExcludedFolder(folders[index].id!);
              },
              onAdd: () async {
                final path = await FilePicker.getDirectoryPath();
                if (path == null) return;
                final repo = await ref.read(libraryRepositoryProvider.future);
                await repo.addExcludedFolder(path);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          FilledButton.icon(
            onPressed: isScanning
                ? null
                : () => ref
                      .read(libraryScanControllerProvider.notifier)
                      .startScan(),
            icon: isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(isScanning ? 'Scanning…' : 'Rescan library'),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          Text('Playback', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.stackSm),
          GlassContainer(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.stackMd,
              vertical: 4,
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Resume after interruption'),
              subtitle: const Text(
                'Automatically resume playback once a phone call or another '
                "app's audio ends.",
              ),
              value: ref.watch(resumeAfterInterruptionProvider).value ?? false,
              onChanged: (value) async {
                final repo = await ref.read(settingsRepositoryProvider.future);
                await repo.setResumeAfterInterruption(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addScanFolder(BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;
    final repo = await ref.read(libraryRepositoryProvider.future);
    await repo.addScanRoot(path);

    final subfolders = await repo.listSubfolders(path);
    if (subfolders.isEmpty || !context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _ExcludeSubfolderSheet(parentPath: path, subfolders: subfolders),
    );
  }
}

/// One "SCANNED FOLDERS" / "EXCLUDED FOLDERS" card body: caps label, list of
/// folder rows with a remove action, and an add button.
class _FolderSection extends StatelessWidget {
  const _FolderSection({
    required this.label,
    required this.icon,
    required this.emptyMessage,
    required this.addLabel,
    required this.itemsAsync,
    required this.onRemove,
    required this.onAdd,
  });

  final String label;
  final IconData icon;
  final String emptyMessage;
  final String addLabel;
  final AsyncValue<List<String>> itemsAsync;
  final void Function(String path, int index) onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.overline.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        itemsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.stackMd),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('Error: $e', style: theme.textTheme.bodySmall),
          data: (paths) {
            if (paths.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.stackSm,
                ),
                child: Text(emptyMessage, style: theme.textTheme.bodySmall),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < paths.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.stackSm),
                        Expanded(
                          child: Text(
                            paths[i],
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 20,
                          ),
                          onPressed: () => onRemove(paths[i], i),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: Text(addLabel),
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}

/// "Exclude a subfolder?" — shown once, right after a new scan root is
/// added, listing its immediate children only (one level, not a recursive
/// tree browser — approved 2026-08-18). Each toggle instantly adds/removes
/// the child from `excluded_folders`; there's no separate save step.
class _ExcludeSubfolderSheet extends ConsumerStatefulWidget {
  const _ExcludeSubfolderSheet({
    required this.parentPath,
    required this.subfolders,
  });

  final String parentPath;
  final List<Directory> subfolders;

  @override
  ConsumerState<_ExcludeSubfolderSheet> createState() =>
      _ExcludeSubfolderSheetState();
}

class _ExcludeSubfolderSheetState
    extends ConsumerState<_ExcludeSubfolderSheet> {
  final Set<String> _excluded = {};

  Future<void> _toggle(String path, bool exclude) async {
    final repo = await ref.read(libraryRepositoryProvider.future);
    if (exclude) {
      await repo.addExcludedFolder(path);
    } else {
      await repo.removeExcludedFolderByPath(path);
    }
    setState(() {
      if (exclude) {
        _excluded.add(path);
      } else {
        _excluded.remove(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exclude a subfolder?', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.stackSm),
            Text(
              'These folders are inside "${p.basename(widget.parentPath)}" — check any '
              'you don\'t want scanned.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final folder in widget.subfolders)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(p.basename(folder.path)),
                      value: _excluded.contains(folder.path),
                      onChanged: (value) =>
                          _toggle(folder.path, value ?? false),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusRegular,
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
