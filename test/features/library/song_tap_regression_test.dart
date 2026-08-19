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
import 'package:ta_music/features/library/screens/library_gallery_screen.dart';
import 'package:ta_music/shared/widgets/song_list_tile.dart';

import '../../fakes/recording_playback_handler.dart';

/// Guard tests for a regression class we've now hit twice on Windows:
/// tapping a song plays the wrong track because the tapped song's index in
/// the queue passed to `playFromSong` doesn't match the song actually
/// tapped. Covers every list screen with its own tap-to-play wiring
/// (Singles, Album detail, Artist detail) so a future edit to any one of
/// them that breaks this is caught immediately instead of only on a
/// Windows device-testing pass.
void main() {
  List<Song> makeSongs(int count) => [
        for (var i = 1; i <= count; i++)
          Song(
            id: i,
            path: 'C:/music/song_$i.mp3',
            title: 'Song $i',
            artist: 'Artist $i',
            dateAdded: DateTime(2026, 1, i),
          ),
      ];

  setUp(() {
    // Default test surface (800x600) isn't tall enough to fit 8 song rows
    // without scrolling — sized up so every tile in these tests is already
    // built and hit-testable without a separate scroll-into-view step.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> growSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('tapping the 5th song in Singles plays that song with the full list as queue',
      (tester) async {
    await growSurface(tester);
    final songs = makeSongs(8);
    final recorder = RecordingPlaybackHandler();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackServiceProvider.overrideWithValue(PlaybackService(recorder)),
          singlesProvider.overrideWith((ref) => Stream.value(songs)),
          allAlbumsProvider.overrideWith((ref) => Stream.value(const [])),
          allArtistsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: LibraryGalleryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Singles'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SongListTile).at(4));
    await tester.pumpAndSettle();

    expect(recorder.playFromSongCalls, hasLength(1));
    final call = recorder.playFromSongCalls.single;
    expect(call.song.id, songs[4].id, reason: 'tapped the 5th song, expected the 5th song');
    expect(call.sourceList, songs, reason: 'queue should be the entire Singles list');
  });

  testWidgets('tapping a track in Album detail plays that track with the album as queue',
      (tester) async {
    await growSurface(tester);
    final songs = makeSongs(6);
    final recorder = RecordingPlaybackHandler();
    const album = Album(id: 1, name: 'Test Album', artist: 'Test Artist');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackServiceProvider.overrideWithValue(PlaybackService(recorder)),
          songsByAlbumProvider.overrideWith((ref, albumId) => Stream.value(songs)),
        ],
        child: const MaterialApp(home: AlbumDetailScreen(album: album)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SongListTile).at(3));
    await tester.pumpAndSettle();

    expect(recorder.playFromSongCalls, hasLength(1));
    final call = recorder.playFromSongCalls.single;
    expect(call.song.id, songs[3].id, reason: 'tapped the 4th track, expected the 4th track');
    expect(call.sourceList, songs, reason: 'queue should be the entire album');
  });

  testWidgets('tapping a track in Artist detail plays that track with the artist songs as queue',
      (tester) async {
    await growSurface(tester);
    final songs = makeSongs(6);
    final recorder = RecordingPlaybackHandler();
    const artist = Artist(id: 1, name: 'Test Artist');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackServiceProvider.overrideWithValue(PlaybackService(recorder)),
          songsByArtistProvider.overrideWith((ref, artistId) => Stream.value(songs)),
        ],
        child: const MaterialApp(home: ArtistDetailScreen(artist: artist)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SongListTile).at(5));
    await tester.pumpAndSettle();

    expect(recorder.playFromSongCalls, hasLength(1));
    final call = recorder.playFromSongCalls.single;
    expect(call.song.id, songs[5].id, reason: 'tapped the last track, expected the last track');
    expect(call.sourceList, songs, reason: 'queue should be the entire artist song list');
  });
}
