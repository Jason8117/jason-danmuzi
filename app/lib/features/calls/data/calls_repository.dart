import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/live_channel.dart';
import '../domain/call_models.dart';
import '../domain/intake_models.dart';

sealed class CallsEvent {
  const CallsEvent();
}

class TasksSnapshot extends CallsEvent {
  const TasksSnapshot(this.tasks);
  final List<CallTask> tasks;
}

class TaskUpdated extends CallsEvent {
  const TaskUpdated(this.task);
  final CallTask task;
}

class TaskDeleted extends CallsEvent {
  const TaskDeleted(this.taskId);
  final String taskId;
}

/// The only place that knows the server's URL layout and wire format.
class CallsRepository {
  CallsRepository(this._api);

  final ApiClient _api;

  CallTask _task(dynamic json) => CallTask.fromJson(json as Map<String, dynamic>);

  Future<ServerInfo> serverInfo() async =>
      ServerInfo.fromJson(await _api.get('/v1/config') as Map<String, dynamic>);

  Future<List<CallTask>> list() async {
    final json = await _api.get('/v1/tasks') as Map<String, dynamic>;
    return (json['tasks'] as List<dynamic>).map(_task).toList();
  }

  Future<CallTask> create(NewCallRequest request) async => _task(await _api.post('/v1/tasks', request.toJson()));

  /// SPEC-INTAKE-001: a plan-card draft for a one-line request. Creates no task. An older server answers 404;
  /// callers tell that apart by `ApiException.statusCode`, because its body carries no error code of ours.
  Future<IntakeResult> intake(String text, CallLanguage language) async => IntakeResult.fromJson(
        await _api.post('/v1/intake', {'text': text, 'language': language.name}) as Map<String, dynamic>,
      );

  Future<CallTask> approvePlan(String id, {String? openingLine}) async => _task(
        await _api.post('/v1/tasks/$id/approve-plan', {
          if (openingLine != null) 'plan': {'openingLine': openingLine},
        }),
      );

  Future<CallTask> cancel(String id) async => _task(await _api.post('/v1/tasks/$id/cancel'));

  Future<CallTask> decide(
    String taskId,
    String approvalId, {
    required bool approve,
    String? comment,
  }) async {
    final trimmed = comment?.trim();
    return _task(
      await _api.post('/v1/tasks/$taskId/approvals/$approvalId', {
        'decision': approve ? 'approve' : 'reject',
        if (trimmed != null && trimmed.isNotEmpty) 'comment': trimmed,
      }),
    );
  }

  Future<void> delete(String id) => _api.delete('/v1/tasks/$id');

  LiveConnection openLiveChannel() => LiveChannel(_api.webSocketUri('/v1/stream'));

  static CallsEvent? parseEvent(Map<String, dynamic> json) {
    return switch (json['type']) {
      'snapshot' => TasksSnapshot(
          (json['tasks'] as List<dynamic>).map((e) => CallTask.fromJson(e as Map<String, dynamic>)).toList(),
        ),
      'task.updated' => TaskUpdated(CallTask.fromJson(json['task'] as Map<String, dynamic>)),
      'task.deleted' => TaskDeleted(json['taskId'] as String),
      _ => null,
    };
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final settings = ref.watch(settingsProvider);
  final client = ApiClient(baseUrl: settings.serverUrl, token: settings.apiToken);
  ref.onDispose(client.close);
  return client;
});

final callsRepositoryProvider = Provider<CallsRepository>((ref) => CallsRepository(ref.watch(apiClientProvider)));

final serverInfoProvider = FutureProvider<ServerInfo>((ref) => ref.watch(callsRepositoryProvider).serverInfo());
