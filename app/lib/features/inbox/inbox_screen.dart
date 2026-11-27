import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// SCR-T01 (SPEC-SHELL-001 REQ-011, REQ-012).
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('tasks-screen'),
      appBar: AppBar(title: const Text('나의 업무')),
      body: const SizedBox.shrink(),
    );
  }
}
