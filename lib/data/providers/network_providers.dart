import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/lyrics/lrclib_client.dart';
import '../services/lyrics/local_lrc_file_reader.dart';
import '../services/translation/translation_client.dart';

/// Shared [Dio] client for the app's outbound HTTP use — lyrics.ovh and
/// LRCLIB lookups. `connectTimeout` lives on [BaseOptions] here since it
/// can't be set per-request via [Options]; callers add their own
/// `sendTimeout`/`receiveTimeout` on top of this as needed.
final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
});

final lrclibClientProvider = Provider<LrclibClient>((ref) {
  return LrclibClient(ref.watch(dioProvider));
});

final localLrcFileReaderProvider = Provider<LocalLrcFileReader>((ref) {
  return LocalLrcFileReader();
});

final translationClientProvider = Provider<TranslationClient>((ref) {
  return TranslationClient(ref.watch(dioProvider));
});
