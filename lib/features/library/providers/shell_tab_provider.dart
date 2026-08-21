import 'package:flutter_riverpod/flutter_riverpod.dart';

// Hand-written provider rather than `@riverpod` codegen — see
// `lib/data/models/song.dart` for why.

/// Which bottom-nav tab (Lounge / The Gallery / Aura) is active. Lives
/// outside the tab bar itself so the nav drawer and Home's quick-access
/// tiles can switch tabs too.
class ShellTabIndex extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

final shellTabIndexProvider = NotifierProvider<ShellTabIndex, int>(ShellTabIndex.new);
