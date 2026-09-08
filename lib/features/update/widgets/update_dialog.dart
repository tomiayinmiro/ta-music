import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/services/update/update_client.dart';

/// "Update Available" dialog — dismissible for a regular new release,
/// non-dismissible (no "Later" button, no tap-outside/back-button dismiss)
/// when the installed version has dropped below `minimum_supported_version`.
/// No Stitch design exists for this (not in DESIGN_MAP.md); styled like
/// `SongInfoDialog`, the one other plain undesigned dialog in the app.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
    required this.manifest,
    required this.installedVersion,
    required this.mandatory,
    this.onLater,
  });

  final UpdateManifest manifest;
  final String installedVersion;
  final bool mandatory;

  /// Called when the user explicitly taps "Later" — never called for
  /// mandatory updates (no such button) and never called just because the
  /// dialog closed some other way, since dismissal-suppression is meant to
  /// track an explicit "not now", not any incidental dismissal.
  final VoidCallback? onLater;

  static Future<void> show(
    BuildContext context, {
    required UpdateManifest manifest,
    required String installedVersion,
    required bool mandatory,
    VoidCallback? onLater,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !mandatory,
      builder: (context) => PopScope(
        canPop: !mandatory,
        child: UpdateDialog(
          manifest: manifest,
          installedVersion: installedVersion,
          mandatory: mandatory,
          onLater: onLater,
        ),
      ),
    );
  }

  String get _downloadUrl => Platform.isAndroid ? manifest.downloadUrlAndroid : manifest.downloadUrlWindows;

  Future<void> _openDownloadUrl(BuildContext context) async {
    final uri = Uri.parse(_downloadUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      Logger().w('[update_check] launchUrl returned false for $uri');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Couldn't open the download page.")));
      }
      return;
    }
    // Mandatory has no way out until the user actually updates — leave it
    // open. A regular update is dismissed once the user has been sent to
    // download it; if they come back without updating, the same version
    // still isn't dismissed, so it reappears next launch.
    if (!mandatory && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.containerMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Update Available', style: AppTypography.headlineMd.copyWith(color: theme.colorScheme.onSurface)),
              const SizedBox(height: AppSpacing.stackMd),
              Text(
                mandatory
                    ? 'This version of TA MUSIC ($installedVersion) is no longer supported. '
                          'Please update to keep using the app.'
                    : 'A new version of TA MUSIC is available.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.stackMd),
              _InfoRow(label: 'Your version', value: installedVersion),
              _InfoRow(label: 'Latest version', value: manifest.latestVersion),
              _InfoRow(label: 'Released', value: formatReleaseDate(manifest.releaseDate)),
              const SizedBox(height: AppSpacing.stackMd),
              Text(
                "What's new",
                style: AppTypography.labelSm.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(manifest.releaseNotes, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.stackLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!mandatory)
                    TextButton(
                      onPressed: () {
                        onLater?.call();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Later'),
                    ),
                  const SizedBox(width: AppSpacing.stackSm),
                  FilledButton(
                    onPressed: () => _openDownloadUrl(context),
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusRegular),
                    ),
                    child: const Text('Download'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppTypography.labelSm.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
