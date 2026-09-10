import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/providers/update_providers.dart';
import '../../../data/repositories/backup_repository.dart';
import '../../../data/services/backup/backup_import_service.dart';
import '../../../data/services/backup/backup_models.dart';
import '../../../shared/widgets/glass_container.dart';

/// Settings > "Backup & Restore" — export/import of playlists, favorites,
/// listening history, Aura stats, manually-added lyrics, and portable
/// preferences (never the music files themselves). See CLAUDE.md's Backup &
/// Restore decisions for the exact data model and the additive-not-
/// destructive import rules `BackupImportService` implements.
///
/// A `ConsumerStatefulWidget` (not stateless) purely to hold the two local
/// `_exporting`/`_importing` loading flags — nothing here is DB-reactive
/// state, so plain widget state fits better than a Riverpod controller for
/// a one-off async action, matching this codebase's existing pattern for
/// e.g. `_ExcludeSubfolderSheet`.
class BackupRestoreSection extends ConsumerStatefulWidget {
  const BackupRestoreSection({super.key});

  @override
  ConsumerState<BackupRestoreSection> createState() => _BackupRestoreSectionState();
}

class _BackupRestoreSectionState extends ConsumerState<BackupRestoreSection> {
  bool _exporting = false;
  bool _importing = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final repo = await ref.read(backupRepositoryProvider.future);
      final packageInfo = await ref.read(packageInfoProvider.future);
      final json = await repo.buildExportJson(appVersion: packageInfo.version);
      final uri = await FilePicker.saveFile(
        fileName: backupFileName(),
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
      );
      if (!mounted) return;
      if (uri != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Backup exported.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (files.isEmpty || !mounted) return;

    setState(() => _importing = true);
    try {
      final bytes = await files.first.readAsBytes();
      final raw = utf8.decode(bytes);
      final repo = await ref.read(backupRepositoryProvider.future);
      final summary = await repo.importFromJson(raw);
      if (!mounted) return;
      await _showSummaryDialog(summary);
    } on BackupFormatException catch (e) {
      if (!mounted) return;
      await _showErrorDialog(e.message);
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog("This backup couldn't be imported: $e");
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _showSummaryDialog(ImportSummary summary) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import complete'),
        content: Text(
          'Imported: ${summary.playlistsImported} playlists, ${summary.favoritesImported} '
          'favorites, ${summary.playsImported} plays, ${summary.manualLyricsImported} manual '
          'lyrics.\nSkipped: ${summary.skipped} items.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Backup & Restore', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.stackSm),
        GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.stackMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EXPORT DATA',
                style: AppTypography.overline.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                'Save your playlists, favorites, listening history, and Aura stats to a file. '
                'Use this to back up your data or transfer it to another device.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.stackMd),
              FilledButton.icon(
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded),
                label: Text(_exporting ? 'Exporting…' : 'Export to file'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.stackMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IMPORT DATA',
                style: AppTypography.overline.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                "Restore your data from a previously exported file. This adds to your current "
                "data — it doesn't replace it.",
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.stackMd),
              OutlinedButton.icon(
                onPressed: _importing ? null : _import,
                icon: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(_importing ? 'Importing…' : 'Import from file'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        Text(
          'Music files themselves are not exported — only your playlists, favorites, '
          'listening history, Aura level, and preferences. To transfer music between '
          'devices, copy your audio files separately.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
