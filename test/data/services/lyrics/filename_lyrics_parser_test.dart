import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/lyrics/filename_lyrics_parser.dart';

void main() {
  group('parseFilenameForLyrics — watermark stripping', () {
    test('strips a dotted site-style watermark, (mp3.pm)', () {
      final result = parseFilenameForLyrics(
        '/Music/Burna_Boy_ft._Ed_Sheeran_-_For_My_Hand_(mp3.pm).mp3',
      );
      expect(result.artist, 'Burna Boy ft. Ed Sheeran');
      expect(result.title, 'For My Hand');
    });

    test('strips a known site keyword watermark, (naijaloaded)', () {
      final result = parseFilenameForLyrics('/Music/Artist_-_Song_(naijaloaded).mp3');
      expect(result.artist, 'Artist');
      expect(result.title, 'Song');
    });

    test('strips (mp3paw)', () {
      final result = parseFilenameForLyrics('Artist - Song (mp3paw).mp3');
      expect(result.artist, 'Artist');
      expect(result.title, 'Song');
    });

    test('does NOT strip a trailing "(Live)" — a version discriminator, not a watermark', () {
      final result = parseFilenameForLyrics('Artist - Song (Live).mp3');
      expect(result.artist, 'Artist');
      expect(result.title, 'Song (Live)');
    });

    test('does NOT strip a trailing "(Remix)"', () {
      final result = parseFilenameForLyrics('Artist - Song (Remix).mp3');
      expect(result.title, 'Song (Remix)');
    });

    test('strips a watermark bracket glued on by a dash, no space', () {
      final result = parseFilenameForLyrics('Sound-Of-Salem-CONNECT-(CeeNaija.com).mp3');
      expect(result.title, 'Sound-Of-Salem-CONNECT');
    });
  });

  group('parseFilenameForLyrics — underscore/whitespace normalization', () {
    test('underscores become spaces and whitespace collapses', () {
      final result = parseFilenameForLyrics('Dua_Lipa_-_Lost_In_Your_Light_feat._Miguel.mp3');
      expect(result.artist, 'Dua Lipa');
      expect(result.title, 'Lost In Your Light feat. Miguel');
    });
  });

  group('parseFilenameForLyrics — dash splitting', () {
    test('2 parts: artist then title', () {
      final result = parseFilenameForLyrics('Artist - Song Title.mp3');
      expect(result.artist, 'Artist');
      expect(result.title, 'Song Title');
    });

    test('1 part (no dash): whole thing is the title, artist stays null', () {
      final result = parseFilenameForLyrics('Untagged Track.mp3');
      expect(result.artist, isNull);
      expect(result.title, 'Untagged Track');
    });

    test('3+ parts: artist, then remaining parts rejoined with " - "', () {
      final result = parseFilenameForLyrics('Artist - Song - Remix.mp3');
      expect(result.artist, 'Artist');
      expect(result.title, 'Song - Remix');
    });

    test('en dash and em dash variants are also recognized', () {
      expect(parseFilenameForLyrics('Artist – Song.mp3').artist, 'Artist');
      expect(parseFilenameForLyrics('Artist — Song.mp3').artist, 'Artist');
    });

    test('a bare hyphen with no surrounding spaces does not split (e.g. Afro-pop)', () {
      final result = parseFilenameForLyrics('Afro-pop Anthem.mp3');
      expect(result.artist, isNull);
      expect(result.title, 'Afro-pop Anthem');
    });

    test('bare-dash fallback: exactly 2 segments with no spaces at all splits as artist/title', () {
      final result = parseFilenameForLyrics('Wizkid-Essence.mp3');
      expect(result.artist, 'Wizkid');
      expect(result.title, 'Essence');
      expect(result.isAmbiguous, isFalse);
    });

    test(
      'bare-dash fallback: 3+ segments with no spaces at all is ambiguous — '
      'whole name becomes the title, artist stays null, flagged isAmbiguous',
      () {
        final result = parseFilenameForLyrics('Sound-Of-Salem-CONNECT-(CeeNaija.com).mp3');
        expect(result.artist, isNull);
        expect(result.title, 'Sound-Of-Salem-CONNECT');
        expect(result.isAmbiguous, isTrue);
      },
    );
  });

  group('parseFilenameForLyrics — pathological cases', () {
    test('a numeric-only filename with no dash yields a title but no artist', () {
      final result = parseFilenameForLyrics('/Music/138697771_.mp3');
      expect(result.artist, isNull);
      expect(result.title, '138697771');
    });

    test('handles a Windows-style backslash path', () {
      final result = parseFilenameForLyrics(r'C:\Music\Artist - Song.mp3');
      expect(result.artist, 'Artist');
      expect(result.title, 'Song');
    });
  });

  group('resolveArtistTitleForLyrics', () {
    test('valid ID3 on both fields is used as-is, filename never consulted', () {
      final result = resolveArtistTitleForLyrics(
        id3Artist: 'Real Artist',
        id3Title: 'Real Title',
        audioFilePath: '/Music/138697771_.mp3',
      );
      expect(result.artist, 'Real Artist');
      expect(result.title, 'Real Title');
      expect(result.usedFilenameFallback, isFalse);
    });

    test('missing ID3 falls back to the filename split', () {
      final result = resolveArtistTitleForLyrics(
        id3Artist: null,
        id3Title: null,
        audioFilePath: '/Music/Burna_Boy_ft._Ed_Sheeran_-_For_My_Hand_(mp3.pm).mp3',
      );
      expect(result.artist, 'Burna Boy ft. Ed Sheeran');
      expect(result.title, 'For My Hand');
      expect(result.usedFilenameFallback, isTrue);
    });

    test('only artist missing: ID3 title is kept, only artist is filled from filename', () {
      final result = resolveArtistTitleForLyrics(
        id3Artist: null,
        id3Title: 'The Real Title Tag',
        audioFilePath: '/Music/Some Artist - Some Song.mp3',
      );
      expect(result.artist, 'Some Artist');
      expect(result.title, 'The Real Title Tag');
      expect(result.usedFilenameFallback, isTrue);
    });

    test('a filename with no dash yields a title but never an artist — bail out', () {
      final result = resolveArtistTitleForLyrics(
        id3Artist: null,
        id3Title: null,
        audioFilePath: '/Music/138697771_.mp3',
      );
      // artist stays null (no dash to split on), so this song's lyrics
      // lookup is still a bail-out even though the title got filled in.
      expect(result.artist, isNull);
      expect(result.title, '138697771');
    });

    test('no audio file path at all: no fallback attempted', () {
      final result = resolveArtistTitleForLyrics(id3Artist: null, id3Title: null);
      expect(result.artist, isNull);
      expect(result.title, isNull);
      expect(result.usedFilenameFallback, isFalse);
    });

    test(
      'a filename with 3+ bare-dash segments resolves to a null artist and sets '
      'filenameAmbiguous',
      () {
        final result = resolveArtistTitleForLyrics(
          id3Artist: null,
          id3Title: null,
          audioFilePath: '/Music/Sound-Of-Salem-CONNECT-(CeeNaija.com).mp3',
        );
        expect(result.artist, isNull);
        expect(result.title, 'Sound-Of-Salem-CONNECT');
        expect(result.filenameAmbiguous, isTrue);
      },
    );
  });

  group('resolveArtistTitleForLyrics — placeholder ID3 tags treated as missing', () {
    test('artist "Unknown Artist" is rejected, filename fallback used', () {
      final result = resolveArtistTitleForLyrics(
        id3Artist: 'Unknown Artist',
        id3Title: null,
        audioFilePath: '/Music/Edd_Sheeran_-_Shape_Of_You_(mp3.pm).mp3',
      );
      expect(result.artist, 'Edd Sheeran');
      expect(result.title, 'Shape Of You');
      expect(result.usedFilenameFallback, isTrue);
    });

    test('artist "unknown artist" is rejected case-insensitively', () {
      final result = resolveArtistTitleForLyrics(
        id3Artist: 'unknown artist',
        id3Title: 'Real Title',
        audioFilePath: '/Music/Some Artist - Real Title.mp3',
      );
      expect(result.artist, 'Some Artist');
      expect(result.title, 'Real Title');
    });

    test('artist "Unknown" is rejected', () {
      final result = resolveArtistTitleForLyrics(
        id3Artist: 'Unknown',
        id3Title: 'Real Title',
        audioFilePath: '/Music/Some Artist - Real Title.mp3',
      );
      expect(result.artist, 'Some Artist');
    });

    test('artist "Various Artists" is rejected only when title is also missing', () {
      final rejected = resolveArtistTitleForLyrics(
        id3Artist: 'Various Artists',
        id3Title: null,
        audioFilePath: '/Music/Some Artist - Real Title.mp3',
      );
      expect(rejected.artist, 'Some Artist');

      final kept = resolveArtistTitleForLyrics(
        id3Artist: 'Various Artists',
        id3Title: 'Real Title',
        audioFilePath: '/Music/Some Artist - Real Title.mp3',
      );
      expect(kept.artist, 'Various Artists');
      expect(kept.title, 'Real Title');
      expect(kept.usedFilenameFallback, isFalse);
    });

    test('artist "Track" (the bare word) is rejected, but "Track 1" is kept', () {
      final rejected = resolveArtistTitleForLyrics(
        id3Artist: 'Track',
        id3Title: 'Real Title',
        audioFilePath: '/Music/Some Artist - Real Title.mp3',
      );
      expect(rejected.artist, 'Some Artist');

      final kept = resolveArtistTitleForLyrics(
        id3Artist: 'Track 1',
        id3Title: 'Real Title',
        audioFilePath: '/Music/Some Artist - Real Title.mp3',
      );
      expect(kept.artist, 'Track 1');
    });

    test('artist made only of dashes/dots/underscores/whitespace is rejected', () {
      for (final placeholder in ['---', '___', '...', '  ', '- . _']) {
        final result = resolveArtistTitleForLyrics(
          id3Artist: placeholder,
          id3Title: 'Real Title',
          audioFilePath: '/Music/Some Artist - Real Title.mp3',
        );
        expect(result.artist, 'Some Artist', reason: 'placeholder="$placeholder"');
      }
    });

    test('title "Untitled" is rejected, filename fallback used', () {
      final result = resolveArtistTitleForLyrics(
        id3Artist: 'Real Artist',
        id3Title: 'Untitled',
        audioFilePath: '/Music/Real Artist - Real Title.mp3',
      );
      expect(result.artist, 'Real Artist');
      expect(result.title, 'Real Title');
    });

    test('title "Track" (bare word) is rejected', () {
      final result = resolveArtistTitleForLyrics(
        id3Artist: 'Real Artist',
        id3Title: 'Track',
        audioFilePath: '/Music/Real Artist - Real Title.mp3',
      );
      expect(result.title, 'Real Title');
    });

    test('title "Unknown Title" is rejected', () {
      final result = resolveArtistTitleForLyrics(
        id3Artist: 'Real Artist',
        id3Title: 'Unknown Title',
        audioFilePath: '/Music/Real Artist - Real Title.mp3',
      );
      expect(result.title, 'Real Title');
    });

    test('title made only of dashes/dots/underscores/whitespace is rejected', () {
      final result = resolveArtistTitleForLyrics(
        id3Artist: 'Real Artist',
        id3Title: '____',
        audioFilePath: '/Music/Real Artist - Real Title.mp3',
      );
      expect(result.title, 'Real Title');
    });

    test('a legitimate title that merely contains "track", e.g. "Soundtrack", is kept', () {
      final result = resolveArtistTitleForLyrics(
        id3Artist: 'Real Artist',
        id3Title: 'Soundtrack',
        audioFilePath: '/Music/Real Artist - Real Title.mp3',
      );
      expect(result.title, 'Soundtrack');
    });
  });
}
