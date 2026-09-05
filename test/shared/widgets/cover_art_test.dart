import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/models/song.dart';
import 'package:ta_music/data/services/fallback_cover_resolver.dart';
import 'package:ta_music/shared/widgets/cover_art.dart';

Song _song({String? path, String? title}) {
  return Song(
    id: 1,
    path: path ?? 'C:/music/artist/song.mp3',
    title: title,
    dateAdded: DateTime(2026, 1, 1),
  );
}

/// [CoverArt] always sets `cacheWidth`/`cacheHeight`, which wraps the
/// underlying provider in a [ResizeImage] — unwrap it to inspect what's
/// actually being displayed.
ImageProvider _unwrap(ImageProvider provider) =>
    provider is ResizeImage ? provider.imageProvider : provider;

void main() {
  testWidgets('a real path bypasses the fallback entirely', (tester) async {
    final tempFile = File('${Directory.systemTemp.path}/cover_art_test_${DateTime.now().microsecondsSinceEpoch}.jpg');
    tempFile.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]); // minimal JPEG-ish bytes
    addTearDown(() => tempFile.deleteSync());

    await tester.pumpWidget(
      MaterialApp(
        home: CoverArt(path: tempFile.path, size: 48, song: _song()),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(_unwrap(image.image), isA<FileImage>());
  });

  testWidgets('no real path but a song present shows the resolved fallback asset', (tester) async {
    final song = _song(path: 'C:/music/burna_boy/last_last.mp3');
    final expectedAsset = FallbackCoverResolver.resolveFor(song);

    await tester.pumpWidget(
      MaterialApp(
        home: CoverArt(path: null, size: 48, song: song),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    final assetImage = _unwrap(image.image) as AssetImage;
    expect(assetImage.assetName, expectedAsset);
  });

  testWidgets('a detected Bible file shows the shared bible asset', (tester) async {
    final song = _song(title: 'The Holy Bible - Genesis', path: 'C:/audio/track01.mp3');

    await tester.pumpWidget(
      MaterialApp(
        home: CoverArt(path: null, size: 48, song: song),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final assetImage = _unwrap(image.image) as AssetImage;
    expect(assetImage.assetName, FallbackCoverResolver.bibleAssetPath);
  });

  testWidgets('no path and no song falls back to the plain placeholder icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CoverArt(path: null, size: 48),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });

  testWidgets('missing file on disk falls back to a fallback asset when a song is given', (tester) async {
    final song = _song(path: 'C:/music/artist/song.mp3');

    await tester.pumpWidget(
      MaterialApp(
        home: CoverArt(path: 'C:/does/not/exist.jpg', size: 48, song: song),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(_unwrap(image.image), isA<AssetImage>());
  });
}
