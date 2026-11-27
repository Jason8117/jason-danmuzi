import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// SCR-M01 (SPEC-SHELL-001 REQ-017).
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('me-screen'),
      appBar: AppBar(title: const Text('내 정보')),
      body: const SizedBox.shrink(),
    );
  }
}
