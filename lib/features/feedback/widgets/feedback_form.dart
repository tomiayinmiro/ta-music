import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/theme/spacing.dart';
import '../../../data/models/feedback_type.dart';
import '../../../data/providers/network_providers.dart';
import '../../../data/services/feedback/feedback_client.dart';
import '../../../shared/widgets/glass_container.dart';

enum _SubmitStatus { idle, submitting, success, error }

/// The Feedback tab of the Feedback & Help screen — bug report / feature
/// request / general comment, posted to Web3Forms. No Stitch design exists
/// for this screen (see DESIGN_MAP.md); fields follow the same plain
/// TextField-with-errorText pattern as `ManualLyricsEditorScreen`.
class FeedbackForm extends ConsumerStatefulWidget {
  const FeedbackForm({super.key});

  @override
  ConsumerState<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends ConsumerState<FeedbackForm> {
  FeedbackType? _type;
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();

  String? _typeError;
  String? _subjectError;
  String? _messageError;

  _SubmitStatus _status = _SubmitStatus.idle;
  String? _errorMessage;
  Timer? _autoPopTimer;

  @override
  void dispose() {
    _autoPopTimer?.cancel();
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    setState(() {
      _typeError = _type == null ? 'Choose a feedback type.' : null;
      _subjectError = subject.isEmpty ? 'Subject is required.' : null;
      _messageError = message.isEmpty ? 'Message is required.' : null;
    });
    if (_typeError != null || _subjectError != null || _messageError != null) return;

    setState(() {
      _status = _SubmitStatus.submitting;
      _errorMessage = null;
    });

    final client = ref.read(feedbackClientProvider);
    final result = await client.submit(
      type: _type!,
      subject: subject,
      message: message,
      email: _emailController.text,
      appVersion: kAppVersion,
      platform: Platform.isAndroid ? 'Android' : 'Windows',
    );

    if (!mounted) return;

    switch (result) {
      case FeedbackSubmitSuccess():
        setState(() => _status = _SubmitStatus.success);
        _type = null;
        _subjectController.clear();
        _messageController.clear();
        _emailController.clear();
        _autoPopTimer = Timer(const Duration(seconds: 2), () {
          if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
        });
      case FeedbackSubmitFailure(:final message):
        setState(() {
          _status = _SubmitStatus.error;
          _errorMessage = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitting = _status == _SubmitStatus.submitting;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      children: [
        Text(
          "Found a bug, or have an idea? Let us know — messages go straight to the developer's "
          'inbox.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.stackLg),
        if (_status == _SubmitStatus.success)
          _StatusBanner(
            icon: Icons.check_circle_outline_rounded,
            color: theme.colorScheme.primary,
            message: 'Thank you! Your feedback has been sent.',
          ),
        if (_status == _SubmitStatus.error)
          _StatusBanner(
            icon: Icons.error_outline_rounded,
            color: theme.colorScheme.error,
            message: _errorMessage ??
                'Something went wrong. Please check your internet connection and try again.',
          ),
        if (_status == _SubmitStatus.success || _status == _SubmitStatus.error)
          const SizedBox(height: AppSpacing.stackMd),
        DropdownButtonFormField<FeedbackType>(
          initialValue: _type,
          decoration: InputDecoration(labelText: 'Type', errorText: _typeError),
          hint: const Text('Select type'),
          items: [
            for (final type in FeedbackType.values)
              DropdownMenuItem(value: type, child: Text(type.label)),
          ],
          onChanged: submitting ? null : (value) => setState(() => _type = value),
        ),
        const SizedBox(height: AppSpacing.stackMd),
        TextField(
          controller: _subjectController,
          enabled: !submitting,
          decoration: InputDecoration(labelText: 'Subject', errorText: _subjectError),
        ),
        const SizedBox(height: AppSpacing.stackMd),
        TextField(
          controller: _messageController,
          enabled: !submitting,
          decoration: InputDecoration(labelText: 'Message', errorText: _messageError),
          maxLines: 8,
          minLines: 4,
        ),
        const SizedBox(height: AppSpacing.stackMd),
        TextField(
          controller: _emailController,
          enabled: !submitting,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Your email',
            helperText: 'Optional — if you want a reply',
          ),
        ),
        const SizedBox(height: AppSpacing.stackLg),
        FilledButton(
          onPressed: submitting ? null : _submit,
          child: submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_status == _SubmitStatus.error ? 'Retry' : 'Submit'),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.color, required this.message});

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
