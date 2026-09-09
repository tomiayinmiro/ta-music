import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/excluded_folder.dart';
import '../models/playlist.dart';
import '../models/scan_root.dart';
import '../models/song.dart';
import '../repositories/library_repository.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/reactive_query.dart';
import '../services/library_scanner.dart';
import '../services/stats_service.dart';
import 'repository_providers.dart';

// Hand-written providers rather than `@riverpod` codegen — see
// `lib/data/models/song.dart` for why.

final allVisibleSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final repo = await ref.watch(songRepositoryProvider.future);
  yield* repo.watchAllVisible();
});

final singlesProvider = StreamProvider<List<Song>>((ref) async* {
  final repo = await ref.watch(songRepositoryProvider.future);
  yield* repo.watchSingles();
});

final recentlyAddedSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final repo = await ref.watch(songRepositoryProvider.future);
  yield* repo.watchRecentlyAdded();
});

final recentlyPlayedSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final repo = await ref.watch(songRepositoryProvider.future);
  yield* repo.watchRecentlyPlayed();
});

final librarySizeProvider = StreamProvider<int>((ref) async* {
  final repo = await ref.watch(songRepositoryProvider.future);
  yield* repo.watchLibrarySize();
});

final songsByAlbumProvider = StreamProvider.family<List<Song>, int>((ref, albumId) async* {
  final repo = await ref.watch(songRepositoryProvider.future);
  yield* repo.watchByAlbum(albumId);
});

final songsByArtistProvider = StreamProvider.family<List<Song>, int>((ref, artistId) async* {
  final repo = await ref.watch(songRepositoryProvider.future);
  yield* repo.watchByArtist(artistId);
});

final allAlbumsProvider = StreamProvider<List<Album>>((ref) async* {
  final repo = await ref.watch(albumRepositoryProvider.future);
  yield* repo.watchAll();
});

/// A single album by id — used wherever only a `Song.albumId` is on hand
/// and its cover art is needed (song rows/cards throughout the app, the
/// mini player, Now Playing, the queue).
///
/// A reactive `StreamProvider`, not a one-shot `FutureProvider` — cover art
/// investigation (2026-09-04): this used to be a plain `Future<Album?>`
/// fetch, cached by Riverpod for the lifetime of the app per `albumId` with
/// nothing to invalidate it. A widget that watched a given album before its
/// `covers/{id}.jpg` had actually been (re)generated — e.g. the mini player,
/// mounted from app start, resolving an album whose cover the background
/// scanner hadn't reached yet — would keep that cached `null` for the rest
/// of the session, even after the scan wrote a real `cover_art_path`,
/// because nothing ever re-ran the fetch. `watchQuery` (the same
/// reactive-streams-over-sqflite pattern every other DB-backed provider in
/// this file already uses) re-emits whenever the `albums` table changes, so
/// a cover art write is picked up live instead of requiring a fresh
/// `albumId` or an app restart.
final albumByIdProvider = StreamProvider.family<Album?, int>((ref, albumId) async* {
  final repo = await ref.watch(albumRepositoryProvider.future);
  yield* watchQuery({'albums'}, () => repo.getById(albumId));
});

final allArtistsProvider = StreamProvider<List<Artist>>((ref) async* {
  final repo = await ref.watch(artistRepositoryProvider.future);
  yield* repo.watchAll();
});

/// Favorites resolved to their [Song] rows, sorted by play count (0-play
/// songs already excluded upstream) — what the Favorites tab actually
/// renders, since a favorite row alone is just a song id.
final favoriteSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final favoriteRepo = await ref.watch(favoriteRepositoryProvider.future);
  final songRepo = await ref.watch(songRepositoryProvider.future);
  await for (final favorites in favoriteRepo.watchAllSortedByPlayCount()) {
    final songs = <Song>[];
    for (final favorite in favorites) {
      final song = await songRepo.getById(favorite.songId);
      if (song != null) songs.add(song);
    }
    yield songs;
  }
});

final isFavoriteProvider = StreamProvider.family<bool, int>((ref, songId) async* {
  final repo = await ref.watch(favoriteRepositoryProvider.future);
  yield* repo.watchIsFavorite(songId);
});

final allPlaylistsProvider = StreamProvider<List<Playlist>>((ref) async* {
  final repo = await ref.watch(playlistRepositoryProvider.future);
  yield* repo.watchAll();
});

/// Playlists list screen — each entry paired with its song count + total
/// duration, computed alongside the list rather than a per-row round-trip.
final allPlaylistSummariesProvider = StreamProvider<List<PlaylistSummary>>((ref) async* {
  final repo = await ref.watch(playlistRepositoryProvider.future);
  yield* repo.watchAllWithSummaries();
});

final playlistByIdProvider = StreamProvider.family<Playlist?, int>((ref, id) async* {
  final repo = await ref.watch(playlistRepositoryProvider.future);
  yield* repo.watchById(id);
});

final playlistSongsProvider = StreamProvider.family<List<Song>, int>((ref, playlistId) async* {
  final repo = await ref.watch(playlistRepositoryProvider.future);
  yield* repo.watchSongs(playlistId);
});

final scanRootsProvider = StreamProvider<List<ScanRoot>>((ref) async* {
  final repo = await ref.watch(libraryRepositoryProvider.future);
  yield* repo.watchScanRoots();
});

final excludedFoldersProvider = StreamProvider<List<ExcludedFolder>>((ref) async* {
  final repo = await ref.watch(libraryRepositoryProvider.future);
  yield* repo.watchExcludedFolders();
});

final listeningStatsProvider = StreamProvider<ListeningStats>((ref) async* {
  final service = await ref.watch(statsServiceProvider.future);
  yield* service.watch();
});

/// Drives a library scan and exposes its progress. `null` = idle (no scan
/// running and none has run yet this session). UI reads this to show the
/// persistent scan-progress banner.
class LibraryScanController extends Notifier<ScanProgress?> {
  @override
  ScanProgress? build() => null;

  Future<void> startScan() async {
    final repo = await ref.read(libraryRepositoryProvider.future);
    await for (final progress in repo.scan()) {
      state = progress;
    }
  }

  void dismiss() => state = null;
}

final libraryScanControllerProvider = NotifierProvider<LibraryScanController, ScanProgress?>(
  LibraryScanController.new,
);

/// Android storage/audio permission status, checked app-wide rather than
/// locally per-screen — `null` means "not checked yet this app session".
/// [HomeScreen]'s first-launch flow and the persistent [PermissionBanner]
/// both read this single source of truth so they can't drift out of sync.
/// `App`'s `WidgetsBindingObserver` calls [refresh] on launch and whenever
/// the app resumes from the background (e.g. the user granting the
/// permission from the system Settings page and switching back), which is
/// also how a newly-granted permission gets picked up without the user
/// having to manually tap "Rescan library" themselves.
class AndroidPermissionController extends Notifier<StoragePermissionStatus?> {
  @override
  StoragePermissionStatus? build() => null;

  /// Checks current status without prompting. Auto-starts a scan if this
  /// call finds the permission newly granted since the last known status.
  Future<void> refresh() async {
    final repo = await ref.read(libraryRepositoryProvider.future);
    final previous = state;
    state = await repo.checkStoragePermissionStatus();
    _maybeAutoScan(previous, state);
  }

  /// Actively prompts (the OS dialog on Android). Same newly-granted
  /// auto-scan behavior as [refresh].
  Future<void> request() async {
    final repo = await ref.read(libraryRepositoryProvider.future);
    final previous = state;
    state = await repo.requestStoragePermission();
    _maybeAutoScan(previous, state);
  }

  void _maybeAutoScan(StoragePermissionStatus? previous, StoragePermissionStatus? current) {
    final newlyGranted =
        current == StoragePermissionStatus.granted && previous != StoragePermissionStatus.granted;
    if (newlyGranted) ref.read(libraryScanControllerProvider.notifier).startScan();
  }
}

final androidPermissionStatusProvider =
    NotifierProvider<AndroidPermissionController, StoragePermissionStatus?>(
  AndroidPermissionController.new,
);
