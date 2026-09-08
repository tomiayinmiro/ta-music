import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../repositories/update_repository.dart';
import '../services/update/update_client.dart';
import 'network_providers.dart';
import 'repository_providers.dart';

/// The installed app's own version/build/installer-source info. A
/// `FutureProvider` rather than fetched fresh per call — `PackageInfo`
/// never changes for the life of a running process, so one platform-channel
/// round trip per app launch is enough.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

final updateClientProvider = Provider<UpdateClient>((ref) {
  return UpdateClient(ref.watch(dioProvider));
});

final updateRepositoryProvider = FutureProvider<UpdateRepository>((ref) async {
  return UpdateRepository(
    client: ref.watch(updateClientProvider),
    settingsRepository: await ref.watch(settingsRepositoryProvider.future),
  );
});
