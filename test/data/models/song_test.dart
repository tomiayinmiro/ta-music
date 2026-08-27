import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/models/song.dart';

void main() {
  final dateAdded = DateTime(2026, 8, 25);

  Song songWith({String? path, String? title, String? artist}) {
    return Song(path: path ?? '/Music/Song.mp3', title: title, artist: artist, dateAdded: dateAdded);
  }

  group('Song.displayTitle / displayArtist — real ID3 tags are used as-is', () {
    test('valid title and artist tags are shown verbatim', () {
      final song = songWith(
        path: '/Music/whatever.mp3',
        title: 'Real Title',
        artist: 'Real Artist',
      );
      expect(song.displayTitle, 'Real Title');
      expect(song.displayArtist, 'Real Artist');
    });
  });

  group('Song.displayTitle / displayArtist — missing ID3 falls back to filename parsing', () {
    test('Ed Sheeran verification case: missing title, placeholder "Unknown Artist" tag', () {
      final song = songWith(
        path: '/Music/Edd_Sheeran_-_Shape_Of_You_(mp3.pm).mp3',
        title: null,
        artist: 'Unknown Artist',
      );
      expect(song.displayTitle, 'Shape Of You');
      expect(song.displayArtist, 'Edd Sheeran');
    });

    test('a second Ed Sheeran file, same placeholder pattern', () {
      final song = songWith(
        path: '/Music/Edd_Sheeran_-_photograph._(mp3.pm).mp3',
        title: null,
        artist: 'Unknown Artist',
      );
      expect(song.displayTitle, 'photograph');
      expect(song.displayArtist, 'Edd Sheeran');
    });

    test(
      'ambiguous bare-dash filename: title recovered, artist stays "Unknown Artist" '
      '(genuinely no way to know)',
      () {
        final song = songWith(
          path: '/Music/Sound-Of-Salem-CONNECT-(CeeNaija.com).mp3',
          title: null,
          artist: null,
        );
        expect(song.displayTitle, 'Sound-Of-Salem-CONNECT');
        expect(song.displayArtist, 'Unknown Artist');
      },
    );

    test('no title tag, no artist tag, no dash in filename: raw name becomes the title', () {
      final song = songWith(path: '/Music/Untagged Track.mp3', title: null, artist: null);
      expect(song.displayTitle, 'Untagged Track');
      expect(song.displayArtist, 'Unknown Artist');
    });
  });
}
