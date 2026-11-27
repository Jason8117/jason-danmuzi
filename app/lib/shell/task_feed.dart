import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolbi_core/kolbi_core.dart';

import '../core/clock.dart';
import '../features/calls/application/calls_controller.dart';

// The shell hands the task list to the tabs, so inbox, history and me never import features/calls
// (SPEC-SHELL-001 REQ-018). Every count comes from kolbi_core's groupTasks / groupHistory (REQ-013).

/// All tasks, newest first, with the loading and error states of the first load.
final taskListProvider = Provider<AsyncValue<List<CallTask>>>(
  (ref) => ref.watch(sortedTasksProvider),
);

/// Badge, tasks tab and today lists.
final taskGroupsProvider = Provider<TaskGroups>((ref) {
  final tasks =
      ref.watch(callsControllerProvider).value?.values ?? const <CallTask>[];
  return groupTasks(tasks, now: ref.watch(clockProvider)());
});

/// The history tab's days.
final historyDaysProvider = Provider<List<HistoryDay>>((ref) {
  final tasks =
      ref.watch(callsControllerProvider).value?.values ?? const <CallTask>[];
  return groupHistory(tasks, now: ref.watch(clockProvider)());
});

/// Loads the list again, like the home screen's [다시 시도].
void reloadTasks(WidgetRef ref) => ref.invalidate(callsControllerProvider);

/// Pull-to-refresh.
Future<void> refreshTasks(WidgetRef ref) =>
    ref.read(callsControllerProvider.notifier).refresh();
