import 'package:flutter/widgets.dart';

/// Border radius scale extracted from `designs/sonic_sanctuary_2/DESIGN.md`.
///
/// DESIGN.md expresses these in `rem`; converted at 1rem = 16px, which the
/// doc's own prose confirms ("Standard components ... 0.5rem (8px) radius",
/// "Larger containers ... 1.5rem (24px)").
class AppRadius {
  AppRadius._();

  static const double sm = 4; // 0.25rem
  static const double regular = 8; // 0.5rem (DEFAULT)
  static const double md = 12; // 0.75rem
  static const double lg = 16; // 1rem
  static const double xl = 24; // 1.5rem
  static const double full = 9999;

  static const radiusSm = Radius.circular(sm);
  static const radiusRegular = Radius.circular(regular);
  static const radiusMd = Radius.circular(md);
  static const radiusLg = Radius.circular(lg);
  static const radiusXl = Radius.circular(xl);
  static const radiusFull = Radius.circular(full);

  static const borderRadiusSm = BorderRadius.all(radiusSm);
  static const borderRadiusRegular = BorderRadius.all(radiusRegular);
  static const borderRadiusMd = BorderRadius.all(radiusMd);
  static const borderRadiusLg = BorderRadius.all(radiusLg);
  static const borderRadiusXl = BorderRadius.all(radiusXl);
  static const borderRadiusFull = BorderRadius.all(radiusFull);
}
