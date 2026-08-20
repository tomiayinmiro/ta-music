import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/typography.dart';

const _kLetters = [
  '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

/// Buckets [items] by the first letter of [letterOf], for feeding
/// [AlphabetFastScroller.availableLetters] and computing jump targets.
/// Non-alphabetic (or empty) leading characters bucket under `'#'`, matching
/// the widget's own leading tile.
({Set<String> letters, Map<String, int> firstIndexByLetter}) indexByLetter<T>(
  List<T> items,
  String Function(T item) letterOf,
) {
  final letters = <String>{};
  final firstIndex = <String, int>{};
  for (var i = 0; i < items.length; i++) {
    final raw = letterOf(items[i]).trim();
    final first = raw.isEmpty ? '' : raw[0].toUpperCase();
    final letter = RegExp(r'^[A-Z]$').hasMatch(first) ? first : '#';
    letters.add(letter);
    firstIndex.putIfAbsent(letter, () => i);
  }
  return (letters: letters, firstIndexByLetter: firstIndex);
}

/// Contacts-app-style A-Z fast scroller: a vertical letter rail pinned to
/// the right edge of a long list, visible only while the list is actively
/// scrolling or the rail itself is being dragged, fading out shortly after
/// either goes idle. Dragging (or tapping) a letter reports it via
/// [onLetterSelected].
///
/// Deliberately has no idea how the caller's list is laid out — ListView vs
/// GridView, fixed vs variable item extent — so it does no scrolling itself.
/// The caller turns a selected letter into an actual scroll offset in
/// [onLetterSelected], using whatever math fits its own layout. Drop this
/// directly into a `Stack` alongside the scrollable; it positions itself.
class AlphabetFastScroller extends StatefulWidget {
  const AlphabetFastScroller({
    super.key,
    required this.scrollController,
    required this.availableLetters,
    required this.onLetterSelected,
  });

  final ScrollController scrollController;
  final Set<String> availableLetters;
  final void Function(String letter) onLetterSelected;

  @override
  State<AlphabetFastScroller> createState() => _AlphabetFastScrollerState();
}

class _AlphabetFastScrollerState extends State<AlphabetFastScroller> {
  bool _visible = false;
  bool _dragging = false;
  String? _activeLetter;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_dragging) _showTemporarily();
  }

  void _showTemporarily() {
    if (!_visible) setState(() => _visible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted && !_dragging) setState(() => _visible = false);
    });
  }

  void _handleTouch(Offset localPosition, double barHeight) {
    final index = (localPosition.dy / barHeight * _kLetters.length)
        .floor()
        .clamp(0, _kLetters.length - 1);
    final letter = _kLetters[index];
    if (letter == _activeLetter) return;
    setState(() => _activeLetter = letter);
    if (widget.availableLetters.contains(letter)) {
      unawaited(HapticFeedback.selectionClick());
      widget.onLetterSelected(letter);
    }
  }

  void _endTouch() {
    setState(() {
      _dragging = false;
      _activeLetter = null;
    });
    _showTemporarily();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = _visible || _dragging;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !shown,
        child: Align(
          alignment: Alignment.centerRight,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: AppMotion.fast,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barHeight = constraints.maxHeight * 0.72;
                  return SizedBox(
                    height: constraints.maxHeight,
                    child: Stack(
                      alignment: Alignment.centerRight,
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: (d) {
                            setState(() => _dragging = true);
                            _handleTouch(d.localPosition, barHeight);
                          },
                          onVerticalDragUpdate: (d) => _handleTouch(d.localPosition, barHeight),
                          onVerticalDragEnd: (_) => _endTouch(),
                          onVerticalDragCancel: _endTouch,
                          onTapDown: (d) {
                            setState(() => _dragging = true);
                            _handleTouch(d.localPosition, barHeight);
                          },
                          onTapUp: (_) => _endTouch(),
                          child: Container(
                            width: 18,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.75),
                              borderRadius: AppRadius.borderRadiusFull,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final letter in _kLetters)
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        letter,
                                        style: AppTypography.overline.copyWith(
                                          fontSize: 8,
                                          color: !widget.availableLetters.contains(letter)
                                              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                                              : letter == _activeLetter
                                                  ? theme.colorScheme.secondary
                                                  : theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_dragging && _activeLetter != null)
                          Positioned(right: 32, child: _LetterBubble(letter: _activeLetter!)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterBubble extends StatelessWidget {
  const _LetterBubble({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: theme.colorScheme.secondary, shape: BoxShape.circle),
      child: Text(
        letter,
        style: AppTypography.headlineMd.copyWith(color: theme.colorScheme.onSecondary),
      ),
    );
  }
}
