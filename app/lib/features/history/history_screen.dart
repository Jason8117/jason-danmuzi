import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// SCR-R01 (SPEC-SHELL-001 REQ-014).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('history-screen'),
      appBar: AppBar(title: const Text('기록')),
      body: const SizedBox.shrink(),
    );
  }
}
