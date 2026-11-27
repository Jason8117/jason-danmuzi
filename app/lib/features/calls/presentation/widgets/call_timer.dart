import 'dart:async';

import 'package:kolbi_core/kolbi_core.dart';
import 'package:material_ui/material_ui.dart';

/// Time since the call connected, ticking every second; shared by the task screen header and the live
/// call screen (SPEC-ASSIST-001, moved out of call_detail_screen.dart).
class CallTimer extends StatefulWidget {
  const CallTimer({super.key, required this.since, this.style});
  final DateTime since;
  final TextStyle? style;

  @override
  State<CallTimer> createState() => _CallTimerState();
}

class _CallTimerState extends State<CallTimer> {
  late final Timer _timer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    return Text(
      formatDuration(elapsed.isNegative ? Duration.zero : elapsed),
      style: (widget.style ?? Theme.of(context).textTheme.labelLarge)?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
