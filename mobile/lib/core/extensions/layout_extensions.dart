import 'package:flutter/widgets.dart';

extension ResponsiveLayout on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Tablets and desktops get side-by-side layouts.
  bool get isWide => screenWidth >= 900;
}
