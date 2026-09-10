import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/cache_management_repository.dart';
import 'repository_providers.dart';

/// Sizes for the Settings "Storage & Cache" screen. Recomputed on demand via
/// `ref.invalidate(cacheSizesProvider)` after a clear action, rather than a
/// reactive `watchQuery` — a clear is the only thing that changes these
/// sizes meaningfully within a session, and it only ever happens through
/// this same screen, so there's no other writer to react to.
final cacheSizesProvider = FutureProvider<CacheSizes>((ref) async {
  final repo = await ref.watch(cacheManagementRepositoryProvider.future);
  return repo.computeSizes();
});
