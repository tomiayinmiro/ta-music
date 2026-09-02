import 'package:flutter/material.dart';

import '../../../core/theme/theme_data.dart';
import '../../../data/services/translation/mymemory_languages.dart';
import 'lyrics_translation_controller.dart';

/// The translate icon shown next to the Synced/Estimated badge on the
/// karaoke lyrics view — filled and tinted [AppSemanticColors.accent] when
/// translation is on, outlined otherwise.
class TranslateToggleButton extends StatelessWidget {
  const TranslateToggleButton({super.key, required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.extension<AppSemanticColors>()?.accent ?? theme.colorScheme.secondary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: enabled
              ? accent.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
          shape: BoxShape.circle,
        ),
        child: Icon(
          enabled ? Icons.translate_rounded : Icons.translate_outlined,
          size: 16,
          color: enabled ? accent : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Small pill showing MyMemory's detected source language for the current
/// song, next to the translate toggle — only rendered once translation is
/// on and at least one line has resolved (see
/// [LyricsTranslationController.detectedSourceLanguage]).
class SourceLanguageBadge extends StatelessWidget {
  const SourceLanguageBadge({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = translationLanguageForCode(code)?.englishName ?? code.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'from $label',
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// The translated line rendered below a lyric's original text — smaller
/// weight, accent-colored, per CLAUDE.md's lyrics-translation reference. A
/// loading line shows a subtle "…" placeholder so the layout doesn't jump
/// once the real translation arrives; an unavailable line renders nothing
/// (the original text above it is left to stand alone).
class TranslationLineText extends StatelessWidget {
  const TranslationLineText({super.key, required this.state});

  final TranslationLineDisplayState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.extension<AppSemanticColors>()?.accent ?? theme.colorScheme.secondary;
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500);

    return switch (state) {
      TranslationLoading() => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '…',
          textAlign: TextAlign.center,
          style: baseStyle?.copyWith(color: accent.withValues(alpha: 0.5)),
        ),
      ),
      TranslationReady(:final text) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(text, textAlign: TextAlign.center, style: baseStyle?.copyWith(color: accent)),
      ),
      TranslationUnavailable() => const SizedBox.shrink(),
    };
  }
}
