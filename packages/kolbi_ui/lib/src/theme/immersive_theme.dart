import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';

/// SPEC-ASSIST-001 REQ-001 / REQ-011: the immersive dark used by the assistant and the live call screen,
/// whatever the device mode. It is SPEC-DESIGN-001's dark scheme itself (background #11131F, cards #1B1F33),
/// not a second copy of its values.
abstract final class KolbiTheme {
  static ThemeData immersive() => AppTheme.dark();
}
