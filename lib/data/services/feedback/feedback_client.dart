import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../models/feedback_type.dart';

/// The outcome of one Web3Forms submission.
sealed class FeedbackSubmitResult {
  const FeedbackSubmitResult();
}

class FeedbackSubmitSuccess extends FeedbackSubmitResult {
  const FeedbackSubmitSuccess();
}

class FeedbackSubmitFailure extends FeedbackSubmitResult {
  const FeedbackSubmitFailure(this.message);

  final String message;
}

/// Client for Web3Forms (https://web3forms.com) — the free form-submission
/// backend for the in-app Feedback form. No account/backend of our own: the
/// access key below is Web3Forms' public-facing per-form identifier (their
/// own docs say it's safe to embed client-side), not a secret.
class FeedbackClient {
  FeedbackClient(this._dio);

  final Dio _dio;
  final _logger = Logger();

  static const _accessKey = '5a77dac4-0a68-4983-87cc-59288081ad66';
  static const _endpoint = 'https://api.web3forms.com/submit';

  /// Submits one feedback item. [email] is optional — omitted from the body
  /// entirely when blank rather than sent as an empty string, so Web3Forms'
  /// own reply-to handling doesn't try to treat "" as an address.
  Future<FeedbackSubmitResult> submit({
    required FeedbackType type,
    required String subject,
    required String message,
    required String platform,
    required String appVersion,
    String? email,
  }) async {
    final body = <String, dynamic>{
      'access_key': _accessKey,
      'type': type.label,
      'subject': subject,
      'message': message,
      'app_version': appVersion,
      'platform': platform,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _endpoint,
        data: body,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final success = response.data?['success'] == true;
      if (success) return const FeedbackSubmitSuccess();
      final reason = response.data?['message'] as String?;
      _logger.i('[feedback] Web3Forms reported failure: $reason');
      return FeedbackSubmitFailure(reason ?? 'Something went wrong. Please try again.');
    } on DioException catch (e) {
      _logger.i('[feedback] submit FAILED message=${e.message}');
      return FeedbackSubmitFailure(_messageFor(e));
    }
  }

  String _messageFor(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        'Something went wrong. Please check your internet connection and try again.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}
