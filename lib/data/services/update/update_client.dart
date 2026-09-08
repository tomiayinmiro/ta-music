import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// The parsed contents of `latest-version.json`, hosted on GitHub Pages —
/// see CLAUDE.md's update-notification decisions.
@immutable
class UpdateManifest {
  const UpdateManifest({
    required this.latestVersion,
    required this.minimumSupportedVersion,
    required this.releaseDate,
    required this.downloadUrlAndroid,
    required this.downloadUrlWindows,
    required this.releaseNotes,
  });

  final String latestVersion;
  final String minimumSupportedVersion;
  final String releaseDate;
  final String downloadUrlAndroid;
  final String downloadUrlWindows;
  final String releaseNotes;

  /// Throws [FormatException] if a required field is missing or the wrong
  /// type — the caller treats any parse failure as a silent skip.
  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    String field(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('latest-version.json missing required field "$key"');
      }
      return value;
    }

    return UpdateManifest(
      latestVersion: field('latest_version'),
      minimumSupportedVersion: field('minimum_supported_version'),
      releaseDate: field('release_date'),
      downloadUrlAndroid: field('download_url_android'),
      downloadUrlWindows: field('download_url_windows'),
      releaseNotes: field('release_notes'),
    );
  }
}

/// Fetches `latest-version.json` from GitHub Pages. Never throws — every
/// failure (network, timeout, malformed JSON, wrong shape) is logged and
/// reported as `null`, per CLAUDE.md's "never disrupt app usage" rule: a
/// broken or unreachable update check must be indistinguishable from "no
/// update available" to the rest of the app.
class UpdateClient {
  UpdateClient(this._dio);

  final Dio _dio;
  final _logger = Logger();

  static const _url = 'https://tomiayinmiro.github.io/ta-music/latest-version.json';

  Future<UpdateManifest?> fetchLatest() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _url,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final data = response.data;
      if (data == null) {
        _logger.w('[update_check] fetchLatest: empty response body');
        return null;
      }
      return UpdateManifest.fromJson(data);
    } on DioException catch (e) {
      _logger.i('[update_check] fetchLatest FAILED (network): ${e.message}');
      return null;
    } on FormatException catch (e) {
      _logger.w('[update_check] fetchLatest FAILED (malformed JSON): ${e.message}');
      return null;
    }
  }
}
