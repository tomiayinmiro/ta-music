import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../data/models/song.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../playlists/screens/playlists_screen.dart';
import '../providers/shell_scaffold_key_provider.dart';
import '../providers/shell_tab_provider.dart';
import '../screens/recently_added_screen.dart';
import '../../settings/screens/settings_screen.dart';

/// Home / "Lounge" — matches `designs/lounge_home/`, reinterpreted per the
/// 2026-08-17 plan: the editorial "Featured" hero + mood "Vibe" chips (no
/// curator or mood-tagging data source exists locally) become a
/// "Continue Listening" hero driven by the most recently played song, and
/// quick access links to Favorites + Recently Added (Playlists dropped —
/// not built until Phase 4).
///
/// Also owns the Android first-launch permission flow (approved
/// 2026-08-18): a proactive rationale dialog fires once per cold start when
/// permission isn't granted and the library's empty, since this is the
/// user's first impression of the app on Android.
///
/// Quick access grew a third tile (Playlists) in Phase 4 — the two-tile
/// layout above described it as "dropped — not built until Phase 4". Phase
/// 4.5 (approved 2026-08-21) swapped the Favorites tile for Aura — Favorites
/// is still reachable via the song context menu's "Go to Favorites" entry
/// and the nav drawer, just no longer from Home or the bottom nav.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _checkedPermissionThisSession = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptForPermission());
    }
  }

  Future<void> _maybePromptForPermission() async {
    if (_checkedPermissionThisSession || !mounted) return;
    _checkedPermissionThisSession = true;

    final repo = await ref.read(libraryRepositoryProvider.future);
    final status = await repo.checkStoragePermissionStatus();
    // Only the plain "never asked / soft-denied" state gets the proactive
    // dialog. Already-granted needs nothing; permanently-denied would just
    // be nagging on every cold start for something the user already
    // explicitly declined twice — the empty state's "Open Settings" button
    // covers that case instead.
    if (status != StoragePermissionStatus.denied) return;

    final librarySize = await ref.read(librarySizeProvider.future);
    if (librarySize > 0 || !mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Your Music'),
        content: const Text(
          'TA MUSIC needs permission to see the audio files on your device. '
          'This only grants access to audio — nothing else, and everything '
          'stays on your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed == true && mounted) {
      await _requestPermissionAndScan();
    }
  }

  Future<void> _requestPermissionAndScan() async {
    final repo = await ref.read(libraryRepositoryProvider.future);
    final status = await repo.requestStoragePermission();
    if (status == StoragePermissionStatus.granted) {
      ref.read(libraryScanControllerProvider.notifier).startScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final librarySizeAsync = ref.watch(librarySizeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => ref.read(shellScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: const Text('TA MUSIC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Search is coming in a later phase.')),
            ),
          ),
        ],
      ),
      body: librarySizeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (size) {
          if (size > 0) return const _HomeContent();
          return Platform.isAndroid
              ? const _AndroidPermissionEmptyState()
              : EmptyState(
                  icon: Icons.library_music_outlined,
                  title: 'Your library is empty',
                  message: 'Pick folders to scan for music and TA MUSIC will do the rest.',
                  actionLabel: 'Choose folders',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                );
        },
      ),
    );
  }
}

/// Android's empty-library state: permission-first rather than
/// folder-first, since MediaStore needs no folders to be configured at all
/// (2026-08-18 MediaStore migration — see library_scanner.dart).
class _AndroidPermissionEmptyState extends ConsumerStatefulWidget {
  const _AndroidPermissionEmptyState();

  @override
  ConsumerState<_AndroidPermissionEmptyState> createState() => _AndroidPermissionEmptyStateState();
}

class _AndroidPermissionEmptyStateState extends ConsumerState<_AndroidPermissionEmptyState> {
  StoragePermissionStatus? _status;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final repo = await ref.read(libraryRepositoryProvider.future);
    final status = await repo.checkStoragePermissionStatus();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _onGrantAccess() async {
    final repo = await ref.read(libraryRepositoryProvider.future);
    final status = await repo.requestStoragePermission();
    if (!mounted) return;
    setState(() => _status = status);
    if (status == StoragePermissionStatus.granted) {
      ref.read(libraryScanControllerProvider.notifier).startScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == StoragePermissionStatus.granted) {
      final scanState = ref.watch(libraryScanControllerProvider);
      final isScanning = scanState != null && !scanState.isDone && scanState.error == null;
      return EmptyState(
        icon: Icons.library_music_outlined,
        title: 'No music found',
        message: 'TA MUSIC couldn\'t find any audio files on this device yet.',
        actionLabel: isScanning ? null : 'Rescan library',
        onAction: isScanning
            ? null
            : () => ref.read(libraryScanControllerProvider.notifier).startScan(),
      );
    }

    final isPermanentlyDenied = status == StoragePermissionStatus.permanentlyDenied;
    return EmptyState(
      icon: Icons.library_music_outlined,
      title: 'Your library is empty',
      message: isPermanentlyDenied
          ? 'TA MUSIC needs permission to see your audio files. Enable it in '
              'system settings to continue.'
          : 'TA MUSIC needs permission to see the audio files on your device '
              '— nothing else, and everything stays on your device.',
      actionLabel: isPermanentlyDenied ? 'Open Settings' : 'Grant Access',
      onAction: isPermanentlyDenied ? openAppSettings : _onGrantAccess,
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentlyPlayedAsync = ref.watch(recentlyPlayedSongsProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.containerMargin,
        vertical: AppSpacing.stackMd,
      ),
      children: [
        recentlyPlayedAsync.when(
          loading: () => const SizedBox(height: 180),
          error: (_, _) => const SizedBox.shrink(),
          data: (songs) => songs.isEmpty
              ? const _WelcomeHero()
              : _ContinueListeningHero(song: songs.first),
        ),
        const SizedBox(height: AppSpacing.stackLg),
        Row(
          children: [
            Expanded(
              child: _QuickAccessTile(
                icon: Icons.auto_awesome_rounded,
                label: 'Aura',
                onTap: () => ref.read(shellTabIndexProvider.notifier).set(2),
              ),
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: _QuickAccessTile(
                icon: Icons.new_releases_rounded,
                label: 'Recently Added',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecentlyAddedScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: _QuickAccessTile(
                icon: Icons.playlist_play_rounded,
                label: 'Playlists',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.stackLg),
        recentlyPlayedAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (songs) {
            if (songs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Recently Played'),
                const SizedBox(height: AppSpacing.stackSm),
                SizedBox(
                  height: 188,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: songs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.stackSm),
                    itemBuilder: (context, i) {
                      final song = songs[i];
                      return SizedBox(
                        width: 128,
                        child: GestureDetector(
                          onTap: () => ref.read(playbackServiceProvider).playFromSong(song, songs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CoverArt(path: null, size: 128),
                              const SizedBox(height: AppSpacing.stackSm),
                              Text(
                                song.displayTitle,
                                style: Theme.of(context).textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                song.displayArtist,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: AppRadius.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome to your library', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            'Head to The Gallery and play something — it\'ll show up here next time.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ContinueListeningHero extends ConsumerWidget {
  const _ContinueListeningHero({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: AppRadius.borderRadiusLg,
      ),
      child: Row(
        children: [
          const CoverArt(path: null, size: 88),
          const SizedBox(width: AppSpacing.stackMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Continue Listening', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  song.displayTitle,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  song.displayArtist,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.stackSm),
                FilledButton.icon(
                  onPressed: () => ref.read(playbackServiceProvider).playFromSong(song, [song]),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.stackSm,
          vertical: AppSpacing.stackMd,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: AppRadius.borderRadiusMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
