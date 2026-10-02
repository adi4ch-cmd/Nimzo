import 'package:flutter/widgets.dart';

enum ScreenSize { compact, regular, large, tablet }

class Responsive {
  static ScreenSize of(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (w < 360) return ScreenSize.compact;
    if (w < 412) return ScreenSize.regular;
    if (w < 600) return ScreenSize.large;
    return ScreenSize.tablet;
  }

  static double gutter(BuildContext c) => of(c) == ScreenSize.tablet ? 32 : 16;
  static int columns(BuildContext c) => of(c) == ScreenSize.tablet ? 3 : 2;
}
