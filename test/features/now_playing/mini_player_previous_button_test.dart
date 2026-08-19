import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/models/song.dart';
import 'package:ta_music/data/providers/playback_providers.dart';
import 'package:ta_music/data/services/audio_service.dart';
import 'package:ta_music/features/now_playing/widgets/mini_player.dart';

import '../../fakes/fake_playback_handler.dart';

/// Guards against gating the Previous button on `hasPrevious` again.
/// `skipToPrevious()` always restarts the current track when it's more
/// than 3s in — that needs no *actual* previous track to exist — so the
/// button should stay enabled whenever a song is loaded, `hasPrevious` or
/// not. `FakePlaybackHandler.hasPrevious` is always false, which makes it
/// a convenient stand-in for "no real previous track" (e.g. the tapped
/// song landed at shuffle position 0) without needing a real player.
void main() {
  testWidgets('Previous stays enabled even when hasPrevious is false', (
    tester,
  ) async {
    final song = Song(
      id: 1,
      path: 'C:/music/song_1.mp3',
      title: 'Song 1',
      dateAdded: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackServiceProvider.overrideWithValue(
            PlaybackService(FakePlaybackHandler()),
          ),
          currentSongProvider.overrideWith((ref) => Stream.value(song)),
        ],
        child: const MaterialApp(home: Scaffold(body: MiniPlayer())),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
    );
    expect(button.onPressed, isNotNull);
  });
}
