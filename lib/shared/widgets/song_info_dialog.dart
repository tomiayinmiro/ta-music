import 'package:flutter/material.dart';

import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/duration_format.dart';
import '../../data/models/song.dart';

/// Plain metadata dialog for the context menu's "Song info" action.
///
/// No Stitch design exists for this (DESIGN_MAP.md doesn't list one), and
/// it conceptually overlaps with the Liner Notes panel scheduled for Phase
/// 5 (extended track info: credits, lyrics context, album details).
/// Approved 2026-08-18 as a minimal, undesigned stand-in for now, styled
/// with sonic_sanctuary_2 tokens — Phase 5 may replace or absorb it.
class SongInfoDialog extends StatelessWidget {
  const SongInfoDialog({super.key, required this.song});

  final Song song;

  static Future<void> show(BuildContext context, Song song) {
    return showDialog<void>(context: context, builder: (context) => SongInfoDialog(song: song));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String)>[
      ('Title', song.displayTitle),
      ('Artist', song.displayArtist),
      if (song.album != null && song.album!.trim().isNotEmpty) ('Album', song.album!),
      if (song.genre != null && song.genre!.trim().isNotEmpty) ('Genre', song.genre!),
      if (song.year != null) ('Year', '${song.year}'),
      if (song.trackNumber != null) ('Track', '${song.trackNumber}'),
      ('Duration', formatDurationOrUnknown(song.durationMs)),
      if (song.format != null) ('Format', song.format!.toUpperCase()),
      if (song.sampleRate != null) ('Sample rate', '${(song.sampleRate! / 1000).toStringAsFixed(1)} kHz'),
      if (song.bitRate != null) ('Bit rate', '${song.bitRate} kbps'),
      if (song.fileSize != null) ('File size', _formatFileSize(song.fileSize!)),
      ('Play count', '${song.playCount}'),
      ('Path', song.path),
    ];

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
              Text('Song Info', style: AppTypography.headlineMd.copyWith(color: theme.colorScheme.onSurface)),
              const SizedBox(height: AppSpacing.stackMd),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          label,
                          style: AppTypography.labelSm.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.stackSm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}
