import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/library_providers.dart';
import '../../favorites/screens/favorites_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../providers/shell_tab_provider.dart';

/// Combines both nav-drawer designs (`navigation_drawer_side_menu` and
/// `expanded_navigation_drawer_profile_stats`) into one drawer: the
/// "expanded" variant is this same drawer with its Local Stats section
/// tapped open, rather than a separate screen. The header shows a library
/// summary line instead of the designs' account avatar/name/Premium badge
/// (no accounts in this app — approved 2026-08-17), and the item list is
/// scoped to what Phase 2 actually built: Lounge, The Gallery, Local
/// Stats, Settings.
///
/// Gained a "Favorites" entry in Phase 4.5 (approved 2026-08-21): Favorites
/// lost its bottom-nav tab to Aura that phase, so without this entry it was
/// reachable only through a song's context menu.
class AppNavDrawer extends ConsumerStatefulWidget {
  const AppNavDrawer({super.key});

  @override
  ConsumerState<AppNavDrawer> createState() => _AppNavDrawerState();
}

class _AppNavDrawerState extends ConsumerState<AppNavDrawer> {
  bool _statsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedIndex = ref.watch(shellTabIndexProvider);
    final librarySize = ref.watch(librarySizeProvider).valueOrNull ?? 0;
    final artistCount = ref.watch(allArtistsProvider).valueOrNull?.length ?? 0;

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerMargin,
                AppSpacing.stackLg,
                AppSpacing.containerMargin,
                AppSpacing.stackMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TA MUSIC', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    '$librarySize songs · $artistCount artists',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.stackSm),
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Lounge',
              selected: selectedIndex == 0,
              onTap: () => _selectTab(0),
            ),
            _NavItem(
              icon: Icons.library_music_rounded,
              label: 'The Gallery',
              selected: selectedIndex == 1,
              onTap: () => _selectTab(1),
            ),
            _NavItem(
              icon: Icons.favorite_outline_rounded,
              label: 'Favorites',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const FavoritesScreen()));
              },
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Local Stats',
              selected: _statsExpanded,
              trailing: Icon(
                _statsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              ),
              onTap: () => setState(() => _statsExpanded = !_statsExpanded),
            ),
            if (_statsExpanded) const _LocalStatsPanel(),
            const Spacer(),
            const Divider(height: 1),
            _NavItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const SizedBox(height: AppSpacing.stackSm),
          ],
        ),
      ),
    );
  }

  void _selectTab(int index) {
    ref.read(shellTabIndexProvider.notifier).set(index);
    Navigator.of(context).pop();
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: theme.textTheme.titleSmall?.copyWith(color: color)),
      trailing: trailing,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _LocalStatsPanel extends ConsumerWidget {
  const _LocalStatsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(listeningStatsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.containerMargin,
        vertical: AppSpacing.stackSm,
      ),
      child: statsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.stackMd),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => Text('Stats unavailable', style: theme.textTheme.bodySmall),
        data: (stats) {
          if (stats.totalSongsPlayed == 0) {
            return Text(
              'Play something to see your local listening stats here.',
              style: theme.textTheme.bodySmall,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Songs played',
                      value: '${stats.totalSongsPlayed}',
                    ),
                  ),
                  Expanded(
                    child: _StatTile(
                      label: 'Hours listened',
                      value: formatListeningHours(stats.totalListened),
                    ),
                  ),
                ],
              ),
              if (stats.topArtists.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.stackSm),
                Text('Top artists', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                for (final artist in stats.topArtists.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            artist.name,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('${artist.playCount}', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
