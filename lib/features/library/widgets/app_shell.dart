import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/scan_progress_banner.dart';
import '../../favorites/screens/favorites_screen.dart';
import '../../now_playing/widgets/mini_player.dart';
import '../providers/shell_scaffold_key_provider.dart';
import '../providers/shell_tab_provider.dart';
import '../screens/home_screen.dart';
import '../screens/library_gallery_screen.dart';
import 'app_nav_drawer.dart';

/// Root scaffold: drawer + bottom nav (Lounge / The Gallery / Favorites)
/// + the persistent scan-progress banner, per the Phase 2 brief.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabIndexProvider);

    return Scaffold(
      key: ref.watch(shellScaffoldKeyProvider),
      drawer: const AppNavDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: index,
                children: const [
                  HomeScreen(),
                  LibraryGalleryScreen(),
                  FavoritesScreen(),
                ],
              ),
            ),
            const ScanProgressBanner(),
            const MiniPlayer(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(shellTabIndexProvider.notifier).set(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Lounge'),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music_rounded),
            label: 'The Gallery',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }
}
