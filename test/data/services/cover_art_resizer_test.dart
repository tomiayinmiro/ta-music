import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ta_music/data/services/cover_art_resizer.dart';

/// Builds a synthetic JPEG of the given size — a stand-in for an embedded
/// album picture, avoids depending on a real asset file in the test.
List<int> _jpegBytes(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 60, 200));
  return img.encodeJpg(image);
}

void main() {
  group('resizeCoverArt', () {
    test('bounds a large landscape image to maxDimension on its longest side', () {
      final source = _jpegBytes(4000, 2000);
      final result = resizeCoverArt(source, maxDimension: 1024);

      final decoded = img.decodeImage(result)!;
      expect(decoded.width, 1024);
      expect(decoded.height, 512);
    });

    test('bounds a large portrait image to maxDimension on its longest side', () {
      final source = _jpegBytes(1200, 3600);
      final result = resizeCoverArt(source, maxDimension: 1024);

      final decoded = img.decodeImage(result)!;
      expect(decoded.height, 1024);
      expect(decoded.width, closeTo(341, 1)); // 1200 * (1024 / 3600), rounded
    });

    test('preserves aspect ratio rather than forcing square', () {
      final source = _jpegBytes(3000, 2000); // 3:2
      final result = resizeCoverArt(source, maxDimension: 1024);

      final decoded = img.decodeImage(result)!;
      final originalRatio = 3000 / 2000;
      final resizedRatio = decoded.width / decoded.height;
      expect(resizedRatio, closeTo(originalRatio, 0.01));
    });

    test('shrinks file size for an oversized source', () {
      final source = _jpegBytes(4000, 4000);
      final result = resizeCoverArt(source, maxDimension: 1024);

      expect(result.length, lessThan(source.length));
    });

    test('returns bytes unchanged when already within maxDimension', () {
      final source = _jpegBytes(500, 500);
      final result = resizeCoverArt(source, maxDimension: 1024);

      expect(result, source);
    });

    test('returns bytes unchanged when exactly at maxDimension', () {
      final source = _jpegBytes(1024, 768);
      final result = resizeCoverArt(source, maxDimension: 1024);

      expect(result, source);
    });

    test('returns the original bytes for undecodable input rather than throwing', () {
      final garbage = [1, 2, 3, 4, 5];
      final result = resizeCoverArt(garbage, maxDimension: 1024);

      expect(result, garbage);
    });
  });
}
