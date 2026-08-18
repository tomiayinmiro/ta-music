import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import '../../data/providers/repository_providers.dart';

/// Phase 2 has no playback engine yet (that's Phase 3) — tapping a song
/// still needs to do *something* observable, and recording the play keeps
/// stats/favorites/recently-played testable end-to-end in the meantime.
Future<void> playSongStub(BuildContext context, WidgetRef ref, Song song) async {
  if (song.id != null) {
    final repo = await ref.read(songRepositoryProvider.future);
    await repo.recordPlay(song.id!);
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playing "${song.displayTitle}" — playback engine lands in Phase 3')),
    );
  }
}
