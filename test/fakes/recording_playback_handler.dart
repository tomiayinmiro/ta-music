import 'package:ta_music/data/models/song.dart';

import 'fake_playback_handler.dart';

/// One recorded [RecordingPlaybackHandler.playFromSong] invocation.
class PlayFromSongCall {
  const PlayFromSongCall(this.song, this.sourceList);

  final Song song;
  final List<Song> sourceList;
}

/// A [FakePlaybackHandler] that records `playFromSong` calls instead of
/// no-op'ing them, so widget tests can assert exactly which song and queue
/// a tap produced — see `test/features/library/song_tap_regression_test.dart`.
class RecordingPlaybackHandler extends FakePlaybackHandler {
  final List<PlayFromSongCall> playFromSongCalls = [];

  @override
  Future<void> playFromSong(Song song, List<Song> sourceList) async {
    playFromSongCalls.add(PlayFromSongCall(song, sourceList));
  }
}
