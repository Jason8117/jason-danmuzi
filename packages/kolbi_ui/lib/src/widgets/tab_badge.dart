import 'package:material_ui/material_ui.dart';

/// The approval count on the tasks tab (SPEC-SHELL-001 REQ-003). Hidden at zero, "9+" from ten.
/// The screen-reader wording belongs to the tab, so the badge adds none of its own.
class KolbiTabBadge extends StatelessWidget {
  const KolbiTabBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  static String? labelFor(int count) =>
      count <= 0 ? null : (count >= 10 ? '9+' : '$count');

  @override
  Widget build(BuildContext context) {
    final label = labelFor(count);
    if (label == null) return child;
    return ExcludeSemantics(
      child: Badge(label: Text(label), child: child),
    );
  }
}
