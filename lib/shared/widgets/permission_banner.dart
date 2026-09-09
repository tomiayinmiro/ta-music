import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/spacing.dart';
import '../../data/providers/library_providers.dart';
import '../../data/repositories/library_repository.dart';
import 'glass_container.dart';

/// Persistent banner shown above the bottom nav whenever Android's
/// storage/audio permission isn't granted — scanning is pointless without
/// it (see [LibraryRepository.scan]), so this stays visible across every
/// tab (not just inside the library's empty state) until the user grants
/// it. No-op off Android and before the first permission check completes.
class PermissionBanner extends ConsumerWidget {
  const PermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    final status = ref.watch(androidPermissionStatusProvider);
    if (status == null || status == StoragePermissionStatus.granted) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.stackSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: openAppSettings,
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.stackMd),
          child: Row(
            children: [
              Icon(Icons.folder_off_outlined, color: theme.colorScheme.error),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(
                child: Text(
                  'Storage permission required to see your music. Tap to open Settings.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
