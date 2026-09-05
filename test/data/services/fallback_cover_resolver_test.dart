import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/models/song.dart';
import 'package:ta_music/data/services/fallback_cover_resolver.dart';

Song _song({
  int id = 1,
  String? path,
  String? title,
}) {
  return Song(
    id: id,
    path: path ?? 'C:/music/artist_$id/song_$id.mp3',
    title: title,
    dateAdded: DateTime(2026, 1, 1),
  );
}

void main() {
  group('resolveFor — general pool', () {
    test('same song path always produces the same fallback asset', () {
      final song = _song(path: 'C:/music/burna_boy/last_last.mp3');

      final first = FallbackCoverResolver.resolveFor(song);
      final second = FallbackCoverResolver.resolveFor(song);

      expect(first, second);
    });

    test('different songs distribute across the 20-image pool', () {
      final assignedIndices = <String>{};
      for (var i = 0; i < 200; i++) {
        final song = _song(id: i, path: 'C:/music/folder_$i/track_$i.mp3');
        assignedIndices.add(FallbackCoverResolver.resolveFor(song));
      }

      // With 200 distinct paths hashed into 20 buckets, expect the vast
      // majority of buckets to be hit at least once — not all songs piling
      // onto a couple of images.
      expect(assignedIndices.length, greaterThan(15));
    });

    test('resolved asset path always points into the general pool for non-Bible songs', () {
      final song = _song(path: 'C:/music/wizkid/essence.mp3', title: 'Essence');

      final result = FallbackCoverResolver.resolveFor(song);

      expect(result, startsWith('assets/fallback_covers/fallback_'));
      expect(result, isNot(FallbackCoverResolver.bibleAssetPath));
    });

    test('never returns the bible asset for a non-Bible song', () {
      for (var i = 0; i < 50; i++) {
        final song = _song(id: i, path: 'C:/music/artist_$i/song_$i.mp3', title: 'Song $i');
        expect(FallbackCoverResolver.resolveFor(song), isNot(FallbackCoverResolver.bibleAssetPath));
      }
    });
  });

  group('isAudioBible', () {
    test('matches "The Holy Bible" in the title', () {
      final song = _song(title: 'The Holy Bible - Genesis', path: 'C:/audio/track01.mp3');
      expect(FallbackCoverResolver.isAudioBible(song), isTrue);
    });

    test('matches "The Holy Bible" in the filename when title is missing', () {
      final song = _song(path: 'C:/audio/The_Holy_Bible_Genesis.mp3');
      expect(FallbackCoverResolver.isAudioBible(song), isTrue);
    });

    test('matches "Holy Bible" + "KJV"', () {
      final song = _song(title: 'Holy Bible KJV - Exodus', path: 'C:/audio/track02.mp3');
      expect(FallbackCoverResolver.isAudioBible(song), isTrue);
    });

    test('matches "Bible" + a book number pattern', () {
      final song = _song(title: 'Bible Book 02', path: 'C:/audio/track03.mp3');
      expect(FallbackCoverResolver.isAudioBible(song), isTrue);
    });

    test('matches "Bible" + book number from filename with underscores', () {
      final song = _song(path: 'C:/audio/Audio_Bible_Book_14.mp3');
      expect(FallbackCoverResolver.isAudioBible(song), isTrue);
    });

    test('does not match an ordinary song', () {
      final song = _song(title: 'Essence', path: 'C:/music/wizkid/essence.mp3');
      expect(FallbackCoverResolver.isAudioBible(song), isFalse);
    });

    test('does not match a song that merely mentions "bible" in passing', () {
      final song = _song(title: 'Bible Belt Blues', path: 'C:/music/blues/track.mp3');
      expect(FallbackCoverResolver.isAudioBible(song), isFalse);
    });

    test('falls through to false with no title and a non-matching filename', () {
      final song = _song(path: 'C:/music/unknown/track_99.mp3');
      expect(FallbackCoverResolver.isAudioBible(song), isFalse);
    });

    test('all detected Bible files resolve to the shared bible asset', () {
      final titles = [
        'The Holy Bible - Genesis',
        'Holy Bible KJV - Exodus',
        'Bible Book 02',
      ];
      for (final title in titles) {
        final song = _song(title: title, path: 'C:/audio/${title.hashCode}.mp3');
        expect(FallbackCoverResolver.resolveFor(song), FallbackCoverResolver.bibleAssetPath);
      }
    });
  });
}
