import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/models/song.dart';
import 'package:ta_music/data/services/backup/backup_models.dart';
import 'package:ta_music/data/services/backup/song_matcher.dart';

/// Guards the two-tier matching strategy backup import depends on: exact
/// path first, then a title/artist/album/duration fallback for when a
/// backup crosses devices or platforms and paths can never coincide. See
/// `song_matcher.dart`'s doc for why this exists instead of a stable id.
void main() {
  Song song({
    int id = 1,
    String path = '/music/song.mp3',
    String? title = 'Ye',
    String? artist = 'Burna Boy',
    String? album = 'Outside',
    int? durationMs = 200000,
  }) {
    return Song(
      id: id,
      path: path,
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
      dateAdded: DateTime(2024),
    );
  }

  BackupSongRef ref({
    String path = '/music/song.mp3',
    String? title = 'Ye',
    String? artist = 'Burna Boy',
    String? album = 'Outside',
    int? durationMs = 200000,
  }) {
    return BackupSongRef(path: path, title: title, artist: artist, album: album, durationMs: durationMs);
  }

  test('matches on exact path even if metadata differs', () {
    final index = SongMatchIndex([song(id: 1, path: '/music/song.mp3', title: 'Wrong Title')]);
    final matched = index.match(ref(path: '/music/song.mp3', title: 'Ye'));
    expect(matched?.id, 1);
  });

  test('falls back to title+artist+album+duration when the path never matches', () {
    // Windows export path imported on Android \u2014 paths structurally can't align.
    final index = SongMatchIndex([
      song(id: 1, path: '/storage/emulated/0/Music/song.mp3'),
    ]);
    final matched = index.match(ref(path: r'C:\Users\HP\Music\song.mp3'));
    expect(matched?.id, 1);
  });

  test('disambiguates same title+artist by album when duration is missing', () {
    final index = SongMatchIndex([
      song(id: 1, album: 'Album A', durationMs: null),
      song(id: 2, album: 'Album B', durationMs: null),
    ]);
    final matched = index.match(ref(album: 'Album B', durationMs: null));
    expect(matched?.id, 2);
  });

  test('disambiguates same title+artist by duration within a 2s tolerance', () {
    final index = SongMatchIndex([
      song(id: 1, album: null, durationMs: 100000),
      song(id: 2, album: null, durationMs: 200000),
    ]);
    final matched = index.match(ref(album: null, durationMs: 201500));
    expect(matched?.id, 2);
  });

  test('rejects a duration outside the 2s tolerance in favor of no disambiguation match', () {
    // Only one candidate and it's out of tolerance on duration alone \u2014 still
    // returned, since title+artist agreeing is treated as strong enough
    // signal on its own (e.g. a remaster with a slightly different length).
    final index = SongMatchIndex([song(id: 1, album: null, durationMs: 100000)]);
    final matched = index.match(ref(album: null, durationMs: 500000));
    expect(matched?.id, 1);
  });

  test('returns null when title or artist is missing on the reference', () {
    final index = SongMatchIndex([song(id: 1, path: '/a.mp3')]);
    final matched = index.match(
      BackupSongRef(path: '/different-path.mp3', title: null, artist: 'Burna Boy'),
    );
    expect(matched, isNull);
  });

  test('returns null when nothing in the library matches', () {
    final index = SongMatchIndex([song(id: 1, title: 'Different Song')]);
    final matched = index.match(ref(path: '/different-path.mp3'));
    expect(matched, isNull);
  });

  test('title/artist matching is case- and whitespace-insensitive', () {
    final index = SongMatchIndex([song(id: 1, title: '  YE  ', artist: 'burna boy')]);
    final matched = index.match(ref(path: '/different-path.mp3', title: 'ye', artist: 'Burna Boy'));
    expect(matched?.id, 1);
  });
}
