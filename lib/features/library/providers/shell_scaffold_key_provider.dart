import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The outer [AppShell] Scaffold's key — the one that actually owns
/// `drawer: AppNavDrawer()`.
///
/// Home/Gallery/Favorites each have their own nested Scaffold (for their
/// own AppBar), so `Scaffold.of(context)` called from inside one of them
/// resolves to that INNER Scaffold, not the outer shell — its `openDrawer()`
/// is a silent no-op since the inner Scaffold has no drawer. Bug found
/// 2026-08-18 (drawer button did nothing). This key lets any screen open
/// the real shell drawer directly, bypassing the ambiguous context lookup.
final shellScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>((ref) {
  return GlobalKey<ScaffoldState>();
});
