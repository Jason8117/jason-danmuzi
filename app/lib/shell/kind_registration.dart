import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../features/calls/application/calls_controller.dart';
import '../features/calls/presentation/call_detail_screen.dart';
import '../features/calls/presentation/widgets/call_task_tile.dart';

/// The headless kinds the shell registers at start (SPEC-SHELL-001 REQ-007): `call` only.
final taskKindCatalogProvider = Provider<TaskKindCatalog>(
  (ref) => TaskKindCatalog()..register(const CallTaskKind()),
);

/// The screen half of each registered kind.
final taskKindPresentersProvider = Provider<TaskKindPresenters>(
  (ref) => TaskKindPresenters()..register(const CallKindPresenter()),
);

/// How [task] is drawn: its kind's presenter, or the unknown-kind one (REQ-008).
TaskKindPresenter presenterForTask(WidgetRef ref, CallTask task) => ref
    .read(taskKindPresentersProvider)
    .presenterFor(ref.read(taskKindCatalogProvider).resolveTask(task));

/// The call kind: today's existing task row and the existing call detail screen.
class CallKindPresenter extends TaskKindPresenter {
  const CallKindPresenter();

  @override
  String get kindId => kCallKindId;

  @override
  IconData get icon => Icons.call_outlined;

  @override
  Widget buildRow(
    BuildContext context,
    CallTask task, {
    required VoidCallback onTap,
    Widget? trailing,
    String? subtitle,
  }) => CallTaskTile(
    task: task,
    onTap: onTap,
    trailing: trailing,
    subtitle: subtitle,
  );

  @override
  Widget buildDetail(BuildContext context, String taskId) =>
      CallDetailScreen(taskId: taskId);
}

/// `/calls/:id`: the detail screen of the task's kind. Until the task is known (loading, or not found),
/// the call screen shows its own loading and not-found states.
class TaskDetailRoute extends ConsumerWidget {
  const TaskDetailRoute({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskProvider(taskId));
    final presenter = task == null
        ? const CallKindPresenter()
        : presenterForTask(ref, task);
    return presenter.buildDetail(context, taskId);
  }
}
