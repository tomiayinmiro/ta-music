import 'package:flutter/material.dart';

import '../../features/now_playing/widgets/mini_player.dart';

/// A `Scaffold` for every screen reached via `Navigator.push` (Album detail,
/// Artist detail, Settings, Recently Added, and any screen added after
/// them) — everything except Now Playing itself, which is the expanded
/// player and deliberately has no mini player of its own.
///
/// `AppShell` renders [MiniPlayer] as a sibling below its bottom-nav tabs,
/// but that only covers the 3 tab screens living inside its own `Scaffold`.
/// Anything pushed as a new route sits on the same root `Navigator` as
/// `AppShell` and gets its own full-screen `Scaffold`, covering the mini
/// player entirely regardless of which screen it was pushed from. Use this
/// instead of a bare `Scaffold` on any such screen so the mini player stays
/// visible everywhere it should be.
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, this.appBar, required this.body});

  final PreferredSizeWidget? appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      // `AppShell` excludes the bottom inset because its own
      // `bottomNavigationBar` already accounts for it — there's no such bar
      // here, so the mini player needs this screen's own safe-area padding
      // to avoid sitting under the system nav bar/gesture area.
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: body),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}
