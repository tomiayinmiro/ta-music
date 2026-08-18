import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/elevation.dart';
import '../../core/theme/radius.dart';

/// The "glass" surface described in sonic_sanctuary_2's Layer 3/4: a
/// semi-transparent fill with a backdrop blur and a top-weighted 1px edge
/// standing in for a drop shadow. Used anywhere a card/sheet/banner needs
/// to sit visually above the atmospheric background.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.borderRadiusLg,
    this.padding,
    this.margin,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppElevation.glassBlurSigma,
            sigmaY: AppElevation.glassBlurSigma,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppElevation.glassFill,
              borderRadius: borderRadius,
              // A true top-to-bottom gradient border needs a border-image
              // technique this stack has no package for; a solid top-tinted
              // edge is the closest approximation without adding one.
              border: Border.all(
                width: AppElevation.glassBorderWidth,
                color: AppElevation.glassBorderTop,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
