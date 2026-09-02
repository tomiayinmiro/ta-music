import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/models/song.dart';
import '../../../data/providers/lyrics_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/services/lyrics/filename_lyrics_parser.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass_container.dart';

/// "Add lyrics manually" — reached from the Now Playing lyrics panel, either
/// its version-mismatch warning banner or its "No lyrics found" empty
/// state. Lets the user paste lyrics LRCLIB and lyrics.ovh don't have,
/// correcting the Artist/Title first if a garbled ID3 tag is why the
/// automatic lookup failed. See `LyricsRepository.saveManualLyrics` for why
/// the save is keyed off the song's own resolved metadata rather than
/// whatever's typed here, so the entry reliably reattaches on replay.
class ManualLyricsEditorScreen extends ConsumerStatefulWidget {
  const ManualLyricsEditorScreen({super.key, required this.song});

  final Song song;

  @override
  ConsumerState<ManualLyricsEditorScreen> createState() => _ManualLyricsEditorScreenState();
}

// TODO(manual-lyrics-crash-audit): temporary instrumentation added
// 2026-09-01 to chase a reproducible hang/crash entering this screen and
// saving manual lyrics for a specific song — see CLAUDE.md. Remove once
// root-caused.
final _log = Logger();

class _ManualLyricsEditorScreenState extends ConsumerState<ManualLyricsEditorScreen> {
  late final TextEditingController _artistController;
  late final TextEditingController _titleController;
  final _lyricsController = TextEditingController();

  String? _artistError;
  String? _titleError;
  String? _lyricsError;
  bool _saving = false;

  // TODO(manual-lyrics-crash-audit): tracks which char-count thresholds have
  // already been logged for the lyrics field, so a long paste/typing session
  // logs each threshold once rather than on every subsequent keystroke.
  final Set<int> _loggedLengthThresholds = {};
  int _lastLyricsLength = 0;

  @override
  void initState() {
    super.initState();
    _log.i(
      '[manual_lyrics] editor OPENED artist="${widget.song.artist}" '
      'title="${widget.song.title}" path="${widget.song.path}" '
      'durationMs=${widget.song.durationMs} format=${widget.song.format}',
    );
    late final ResolvedArtistTitle resolved;
    try {
      resolved = resolveArtistTitleForLyrics(
        id3Artist: widget.song.artist,
        id3Title: widget.song.title,
        audioFilePath: widget.song.path,
      );
    } catch (e, st) {
      _log.e('[manual_lyrics] resolveArtistTitleForLyrics THREW in initState', error: e, stackTrace: st);
      rethrow;
    }
    _log.i(
      '[manual_lyrics] resolved artist="${resolved.artist}" title="${resolved.title}" '
      'usedFilenameFallback=${resolved.usedFilenameFallback} '
      'filenameAmbiguous=${resolved.filenameAmbiguous}',
    );
    _artistController = TextEditingController(text: resolved.artist ?? widget.song.displayArtist);
    _titleController = TextEditingController(text: resolved.title ?? widget.song.displayTitle);
    _lyricsController.addListener(_onLyricsChanged);
  }

  void _onLyricsChanged() {
    final text = _lyricsController.text;
    final length = text.length;
    final delta = length - _lastLyricsLength;
    _lastLyricsLength = length;

    // TODO(manual-lyrics-crash-audit): a jump of 50+ chars in one change
    // callback isn't achievable by single-key typing — treat it as a
    // paste/autofill/dictation-style bulk insert rather than trying to hook
    // the platform paste action directly (fragile across the OS context
    // menu, Ctrl+V, and long-press "Paste" affordances).
    if (delta >= 50) {
      final longestLine = text.isEmpty
          ? 0
          : text.split(RegExp(r'\r\n|\n')).map((l) => l.length).reduce((a, b) => a > b ? a : b);
      _log.i(
        '[manual_lyrics] PASTE-LIKE bulk insert into lyrics field: +$delta chars '
        '(total=$length, longestLine=$longestLine chars, lineBreaks=${'\n'.allMatches(text).length})',
      );
    } else if (delta != 0) {
      _log.i('[manual_lyrics] user typing in lyrics field (total=$length chars)');
    }

    for (final threshold in const [1000, 5000, 10000]) {
      if (length >= threshold && _loggedLengthThresholds.add(threshold)) {
        _log.i('[manual_lyrics] lyrics field crossed $threshold chars (total=$length)');
      }
    }
  }

  @override
  void dispose() {
    _lyricsController.removeListener(_onLyricsChanged);
    _artistController.dispose();
    _titleController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final artist = _artistController.text.trim();
    final title = _titleController.text.trim();
    final lyrics = _lyricsController.text.trim();
    // TODO(manual-lyrics-crash-audit): remove once root-caused.
    _log.i(
      '[manual_lyrics] SAVE tapped artistLen=${artist.length} titleLen=${title.length} '
      'lyricsLen=${lyrics.length}',
    );
    setState(() {
      _artistError = artist.isEmpty ? 'Artist is required.' : null;
      _titleError = title.isEmpty ? 'Title is required.' : null;
      _lyricsError = lyrics.isEmpty ? 'Paste the lyrics before saving.' : null;
    });
    if (_artistError != null || _titleError != null || _lyricsError != null) {
      _log.i(
        '[manual_lyrics] SAVE blocked by validation '
        'artistError=$_artistError titleError=$_titleError lyricsError=$_lyricsError',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = await ref.read(lyricsRepositoryProvider.future);
      _log.i('[manual_lyrics] calling LyricsRepository.saveManualLyrics');
      await repo.saveManualLyrics(
        song: widget.song,
        displayArtist: artist,
        displayTitle: title,
        lyrics: lyrics,
      );
      _log.i('[manual_lyrics] saveManualLyrics RETURNED — invalidating providers');
      ref.invalidate(lyricsForSongProvider(widget.song));
      ref.invalidate(manualLyricsEntriesProvider);
      ref.invalidate(lyricsCacheStatsProvider);
      _log.i('[manual_lyrics] SAVE complete — popping screen');
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      // TODO(manual-lyrics-crash-audit): remove once root-caused.
      _log.e('[manual_lyrics] SAVE THREW', error: e, stackTrace: st);
      rethrow;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      appBar: AppBar(title: const Text('Add lyrics manually')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          Text(widget.song.displayTitle, style: theme.textTheme.titleLarge),
          Text(widget.song.displayArtist, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.stackLg),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.stackMd),
            child: Text(
              "We couldn't find lyrics for this song. The song may not exist in the online "
              "lyrics database we use yet, or the version you're playing may differ from "
              'what\'s available.\n\n'
              'You can add lyrics manually:\n'
              '1. Search for your song on one of these sites:\n'
              '   • lrclib.net (our main source — check here first)\n'
              '   • genius.com (great for Nigerian and Afrobeats music)\n'
              '   • musixmatch.com\n'
              '   • azlyrics.com\n'
              '   • lyricstranslate.com (good for non-English songs)\n'
              '   • Or search Google: "[song name] [artist] lyrics"\n'
              '2. Copy the lyrics from whichever site has them\n'
              '3. Fill in the Artist and Title exactly as the song is known\n'
              '4. Paste the lyrics below and save\n\n'
              'Your lyrics will show whenever you play this song. If the song later gets '
              'added to LRCLIB, you can delete your manual entry from Settings > Lyrics, and '
              'the app will automatically fetch the updated version.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          TextField(
            controller: _artistController,
            decoration: InputDecoration(labelText: 'Artist', errorText: _artistError),
            // TODO(manual-lyrics-crash-audit): remove once root-caused.
            onChanged: (_) => _log.i('[manual_lyrics] user typing in artist field'),
          ),
          const SizedBox(height: AppSpacing.stackMd),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(labelText: 'Title', errorText: _titleError),
            // TODO(manual-lyrics-crash-audit): remove once root-caused.
            onChanged: (_) => _log.i('[manual_lyrics] user typing in title field'),
          ),
          const SizedBox(height: AppSpacing.stackMd),
          TextField(
            controller: _lyricsController,
            decoration: InputDecoration(labelText: 'Lyrics', errorText: _lyricsError),
            maxLines: 16,
            minLines: 8,
          ),
          const SizedBox(height: AppSpacing.stackLg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.stackMd),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
