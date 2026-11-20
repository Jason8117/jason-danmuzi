import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/live_channel.dart';
import '../data/calls_repository.dart';
import '../domain/call_models.dart';

class LiveStatusController extends Notifier<LiveStatus> {
  @override
  LiveStatus build() => LiveStatus.connecting;

  void set(LiveStatus status) => state = status;
}

final liveStatusProvider = NotifierProvider<LiveStatusController, LiveStatus>(LiveStatusController.new);

/// Source of truth for every call task on screen.
///
/// Loads once over REST, then keeps itself current from the server's live
/// stream. Every message is a full task snapshot carrying a version, and an
/// HTTP response can land after a newer stream event, so the higher version
/// always wins.
class CallsController extends AsyncNotifier<Map<String, CallTask>> {
  CallsRepository get _repo => ref.read(callsRepositoryProvider);

  @override
  Future<Map<String, CallTask>> build() async {
    final repo = ref.watch(callsRepositoryProvider);
    final channel = repo.openLiveChannel();
    final subscriptions = <StreamSubscription<dynamic>>[
      channel.status.listen((status) => ref.read(liveStatusProvider.notifier).set(status)),
      channel.messages.listen((json) {
        final event = CallsRepository.parseEvent(json);
        if (event != null) _apply(event);
      }),
    ];
    ref.onDispose(() {
      for (final s in subscriptions) {
        s.cancel();
      }
      channel.close();
    });
    channel.connect();

    final tasks = await repo.list();
    return _merge(state.value, tasks);
  }

  static CallTask _newer(CallTask? existing, CallTask incoming) =>
      existing != null && existing.version > incoming.version ? existing : incoming;

  /// A snapshot defines which tasks exist; for each one, keep the newer copy.
  static Map<String, CallTask> _merge(Map<String, CallTask>? current, List<CallTask> snapshot) =>
      {for (final t in snapshot) t.id: _newer(current?[t.id], t)};

  void _apply(CallsEvent event) {
    final current = state.value;
    switch (event) {
      case TasksSnapshot(:final tasks):
        state = AsyncData(_merge(current, tasks));
      case TaskUpdated(:final task):
        if (current != null) state = AsyncData({...current, task.id: _newer(current[task.id], task)});
      case TaskDeleted(:final taskId):
        if (current != null) state = AsyncData(Map.of(current)..remove(taskId));
    }
  }

  CallTask _upsert(CallTask task) {
    _apply(TaskUpdated(task));
    return task;
  }

  Future<void> refresh() async {
    final tasks = await _repo.list();
    _apply(TasksSnapshot(tasks));
  }

  Future<CallTask> create(NewCallRequest request) async => _upsert(await _repo.create(request));

  Future<CallTask> approvePlan(String id, {String? openingLine}) async =>
      _upsert(await _repo.approvePlan(id, openingLine: openingLine));

  Future<CallTask> cancel(String id) async => _upsert(await _repo.cancel(id));

  Future<CallTask> decide(
    String taskId,
    String approvalId, {
    required bool approve,
    String? comment,
  }) async =>
      _upsert(await _repo.decide(taskId, approvalId, approve: approve, comment: comment));

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _apply(TaskDeleted(id));
  }
}

final callsControllerProvider =
    AsyncNotifierProvider<CallsController, Map<String, CallTask>>(CallsController.new);

final sortedTasksProvider = Provider<AsyncValue<List<CallTask>>>((ref) {
  return ref.watch(callsControllerProvider).whenData(
        (tasks) => tasks.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
});

final taskProvider = Provider.family<CallTask?, String>((ref, id) {
  return ref.watch(callsControllerProvider.select((value) => value.value?[id]));
});

typedef PendingApproval = ({CallTask task, ApprovalRequest approval});

final pendingApprovalsProvider = Provider<List<PendingApproval>>((ref) {
  final tasks = ref.watch(callsControllerProvider).value?.values ?? const <CallTask>[];
  return [
    for (final task in tasks)
      if (task.pendingApproval case final approval?) (task: task, approval: approval),
  ];
});
