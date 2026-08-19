import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/radius.dart';

/// Album/song/artist cover art with a consistent placeholder when no art
/// has been extracted yet (no embedded picture, no folder.jpg/cover.jpg).
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.path,
    this.size,
    this.borderRadius = AppRadius.borderRadiusMd,
    this.isCircle = false,
  });

  final String? path;
  final double? size;
  final BorderRadius borderRadius;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    final radius = isCircle ? null : borderRadius;

    Widget content;
    if (path != null && File(path!).existsSync()) {
      // Bug 10 (device testing pass): without cacheWidth/cacheHeight,
      // Image.file decodes at the source file's full resolution — often
      // several thousand pixels per side for embedded album art — even
      // when displayed as a 44-48px thumbnail. Every row in every
      // scrolling list (Gallery, Singles, Queue...) was paying that decode
      // cost. Scaled to the actual display size × device pixel ratio, so
      // it still renders crisp.
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final cacheDimension = (size != null && size!.isFinite) ? (size! * dpr).round() : null;
      content = Image.file(
        File(path!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cacheDimension,
        cacheHeight: cacheDimension,
        errorBuilder: (context, error, stack) => _placeholder(context),
      );
    } else {
      content = _placeholder(context);
    }

    return ClipRRect(
      borderRadius: isCircle ? BorderRadius.circular(9999) : radius!,
      child: SizedBox(width: size, height: size, child: content),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: Center(
        child: LayoutBuilder(
          // `size` can be double.infinity (e.g. "fill the grid tile" via
          // Expanded + SizedBox.expand) — sizing the icon straight off it
          // would ask Icon for an infinite fontSize and crash layout, so
          // the actual resolved constraint is used instead whenever `size`
          // isn't a real finite number.
          builder: (context, constraints) {
            final resolved = (size != null && size!.isFinite) ? size! : constraints.maxWidth;
            final iconSize = resolved.isFinite ? resolved * 0.4 : 24.0;
            return Icon(
              Icons.music_note_rounded,
              color: colors.onSurfaceVariant,
              size: iconSize,
            );
          },
        ),
      ),
    );
  }
}
