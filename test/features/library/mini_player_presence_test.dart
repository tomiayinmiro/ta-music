import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/models/album.dart';
import 'package:ta_music/data/models/artist.dart';
import 'package:ta_music/data/models/song.dart';
import 'package:ta_music/data/providers/library_providers.dart';
import 'package:ta_music/data/providers/playback_providers.dart';
import 'package:ta_music/data/services/audio_service.dart';
import 'package:ta_music/features/library/screens/album_detail_screen.dart';
import 'package:ta_music/features/library/screens/artist_detail_screen.dart';
import 'package:ta_music/features/now_playing/widgets/mini_player.dart';

import '../../fakes/fake_playback_handler.dart';

/// Guard against the mini player silently disappearing on any pushed screen
/// again — Album detail and Artist detail both lost it once already because
/// they used a bare `Scaffold` instead of `AppScaffold`.
void main() {
  final song = Song(
    id: 1,
    path: 'C:/music/song_1.mp3',
    title: 'Song 1',
    dateAdded: DateTime(2026, 1, 1),
  );

  testWidgets(
    'mini player is visible on Album detail while a song is playing',
    (tester) async {
      const album = Album(id: 1, name: 'Test Album', artist: 'Test Artist');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackServiceProvider.overrideWithValue(
              PlaybackService(FakePlaybackHandler()),
            ),
            currentSongProvider.overrideWith((ref) => Stream.value(song)),
            songsByAlbumProvider.overrideWith(
              (ref, albumId) => Stream.value([song]),
            ),
          ],
          child: const MaterialApp(home: AlbumDetailScreen(album: album)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MiniPlayer), findsOneWidget);
    },
  );

  testWidgets(
    'mini player is visible on Artist detail while a song is playing',
    (tester) async {
      const artist = Artist(id: 1, name: 'Test Artist');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackServiceProvider.overrideWithValue(
              PlaybackService(FakePlaybackHandler()),
            ),
            currentSongProvider.overrideWith((ref) => Stream.value(song)),
            songsByArtistProvider.overrideWith(
              (ref, artistId) => Stream.value([song]),
            ),
          ],
          child: const MaterialApp(home: ArtistDetailScreen(artist: artist)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MiniPlayer), findsOneWidget);
    },
  );
}
