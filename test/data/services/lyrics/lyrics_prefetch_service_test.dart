import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ta_music/data/models/song.dart';
import 'package:ta_music/data/repositories/lyrics_repository.dart';
import 'package:ta_music/data/services/lyrics/lyrics_prefetch_service.dart';

class _MockLyricsRepository extends Mock implements LyricsRepository {}

Song _song({String artist = 'Artist', String title = 'Title', String path = '/music/a.mp3'}) {
  return Song(path: path, artist: artist, title: title, dateAdded: DateTime(2026, 1, 1));
}

// A short but real delay — the service schedules real `Timer`s (with
// `debounceDuration: Duration.zero` in these tests), so this just lets
// pending timers/microtasks flush before assertions run.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUpAll(() {
    registerFallbackValue(CancelToken());
  });

  late _MockLyricsRepository repository;
  LyricsPrefetchService? service;

  setUp(() {
    repository = _MockLyricsRepository();
    when(
      () => repository.getLyrics(
        artist: any(named: 'artist'),
        title: any(named: 'title'),
        album: any(named: 'album'),
        duration: any(named: 'duration'),
        audioFilePath: any(named: 'audioFilePath'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const LyricsNotFound());
  });

  tearDown(() => service?.dispose());

  test('debounces rapid skips — only the song settled on is fetched', () async {
    service = LyricsPrefetchService(repository: repository, debounceDuration: Duration.zero);

    service!.onSongChanged(_song(title: 'Skipped 1'));
    service!.onSongChanged(_song(title: 'Skipped 2'));
    service!.onSongChanged(_song(title: 'Settled'));
    await _settle();

    verify(
      () => repository.getLyrics(
        artist: any(named: 'artist'),
        title: 'Settled',
        album: any(named: 'album'),
        duration: any(named: 'duration'),
        audioFilePath: any(named: 'audioFilePath'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
    verifyNever(
      () => repository.getLyrics(
        artist: any(named: 'artist'),
        title: 'Skipped 1',
        album: any(named: 'album'),
        duration: any(named: 'duration'),
        audioFilePath: any(named: 'audioFilePath'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
    verifyNever(
      () => repository.getLyrics(
        artist: any(named: 'artist'),
        title: 'Skipped 2',
        album: any(named: 'album'),
        duration: any(named: 'duration'),
        audioFilePath: any(named: 'audioFilePath'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  test('cancels an in-flight fetch when the song changes again before it completes', () async {
    final completer = Completer<LyricsResult>();
    when(
      () => repository.getLyrics(
        artist: any(named: 'artist'),
        title: 'In flight',
        album: any(named: 'album'),
        duration: any(named: 'duration'),
        audioFilePath: any(named: 'audioFilePath'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => completer.future);

    service = LyricsPrefetchService(repository: repository, debounceDuration: Duration.zero);
    service!.onSongChanged(_song(title: 'In flight'));
    await _settle();

    final captured = verify(
      () => repository.getLyrics(
        artist: any(named: 'artist'),
        title: 'In flight',
        album: any(named: 'album'),
        duration: any(named: 'duration'),
        audioFilePath: any(named: 'audioFilePath'),
        cancelToken: captureAny(named: 'cancelToken'),
      ),
    ).captured;
    final token = captured.single as CancelToken;
    expect(token.isCancelled, isFalse);

    service!.onSongChanged(_song(title: 'Next song'));
    expect(token.isCancelled, isTrue);

    completer.complete(const LyricsNotFound());
    await _settle();
  });

  test('does not retry the same song again within the retry gate', () async {
    service = LyricsPrefetchService(
      repository: repository,
      debounceDuration: Duration.zero,
      retryGate: const Duration(hours: 1),
    );

    final song = _song();
    service!.onSongChanged(song);
    await _settle();
    service!.onSongChanged(song);
    await _settle();

    verify(
      () => repository.getLyrics(
        artist: any(named: 'artist'),
        title: any(named: 'title'),
        album: any(named: 'album'),
        duration: any(named: 'duration'),
        audioFilePath: any(named: 'audioFilePath'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  test('retries once the retry gate has elapsed', () async {
    var now = DateTime(2026, 1, 1, 12);
    service = LyricsPrefetchService(
      repository: repository,
      debounceDuration: Duration.zero,
      retryGate: const Duration(hours: 1),
      now: () => now,
    );

    final song = _song();
    service!.onSongChanged(song);
    await _settle();

    now = now.add(const Duration(hours: 2));
    service!.onSongChanged(song);
    await _settle();

    verify(
      () => repository.getLyrics(
        artist: any(named: 'artist'),
        title: any(named: 'title'),
        album: any(named: 'album'),
        duration: any(named: 'duration'),
        audioFilePath: any(named: 'audioFilePath'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(2);
  });

  test('a song with no artist or title is skipped without calling the repository', () async {
    service = LyricsPrefetchService(repository: repository, debounceDuration: Duration.zero);

    service!.onSongChanged(Song(path: '/music/untagged.mp3', dateAdded: DateTime(2026, 1, 1)));
    await _settle();

    verifyNever(
      () => repository.getLyrics(
        artist: any(named: 'artist'),
        title: any(named: 'title'),
        album: any(named: 'album'),
        duration: any(named: 'duration'),
        audioFilePath: any(named: 'audioFilePath'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  test('onSongChanged(null) cancels anything pending without calling the repository', () async {
    service = LyricsPrefetchService(repository: repository, debounceDuration: Duration.zero);

    service!.onSongChanged(_song());
    service!.onSongChanged(null);
    await _settle();

    verifyNever(
      () => repository.getLyrics(
        artist: any(named: 'artist'),
        title: any(named: 'title'),
        album: any(named: 'album'),
        duration: any(named: 'duration'),
        audioFilePath: any(named: 'audioFilePath'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });
}
