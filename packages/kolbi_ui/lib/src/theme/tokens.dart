import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

// @MX:ANCHOR: [AUTO] The one place spacing, corner radius, motion and tap-size numbers live (SPEC-UX-001 REQ-001).
// @MX:REASON: Screens use these names instead of literals; AC-001 greps the screen files for numeric literals.

/// Spacing scale: 4 · 8 · 12 · 16 · 20 · 24 · 32.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Corner radius scale: 12 · 16 · 20 · pill.
abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double pill = 999;
}

/// Motion: transitions 150 · 250 · 400 ms, and the live-dot cycle.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);

  /// One half-cycle of the pulsing live dot.
  static const pulse = Duration(milliseconds: 1100);
}

/// Smallest side of anything the user taps.
const double kMinTapTarget = 48;

/// [token], or zero while the device asks for reduced motion (REQ-006).
Duration motionDuration(BuildContext context, Duration token) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? Duration.zero : token;

/// `animateTo` asserts on a zero duration, so reduced motion jumps instead (REQ-006).
void scrollToOffset(ScrollController controller, double offset, Duration duration) {
  if (!controller.hasClients) return;
  if (duration == Duration.zero) {
    controller.jumpTo(offset);
  } else {
    controller.animateTo(offset, duration: duration, curve: Curves.easeOut);
  }
}

/// WCAG 2.1 relative luminance of an opaque color.
double relativeLuminance(Color color) {
  double channel(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

/// WCAG 2.1 contrast ratio, 1.0 .. 21.0.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final (hi, lo) = la >= lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}
