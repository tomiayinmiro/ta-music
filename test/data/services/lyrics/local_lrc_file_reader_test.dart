import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/lyrics/local_lrc_file_reader.dart';

void main() {
  group('lrcSidecarPathFor', () {
    test('replaces the extension with .lrc, same folder', () {
      expect(
        lrcSidecarPathFor('/Music/Wizkid/Essence.mp3'),
        '/Music/Wizkid/Essence.lrc',
      );
    });

    test('handles Windows-style backslash paths', () {
      expect(
        lrcSidecarPathFor(r'C:\Music\Wizkid\Essence.mp3'),
        r'C:\Music\Wizkid\Essence.lrc',
      );
    });

    test('a dot in a folder name is not mistaken for the extension', () {
      expect(
        lrcSidecarPathFor('/Music/Best of 2026/Essence.flac'),
        '/Music/Best of 2026/Essence.lrc',
      );
    });

    test('a file with no extension at all just appends .lrc', () {
      expect(lrcSidecarPathFor('/Music/Essence'), '/Music/Essence.lrc');
    });
  });

  group('LocalLrcFileReader.read', () {
    test('returns null for a path with no sidecar file', () async {
      final reader = LocalLrcFileReader();
      final result = await reader.read('/definitely/does/not/exist/Song.mp3');
      expect(result, isNull);
    });
  });
}
