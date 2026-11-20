import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/features/calls/application/calls_controller.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

void main() {
  late FakeCallsRepository repo;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = FakeCallsRepository([]);
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      callsRepositoryProvider.overrideWithValue(repo),
    ]);
    await container.read(callsControllerProvider.future);
  });

  tearDown(() => container.dispose());

  test('a slow HTTP response never overwrites a newer stream update', () async {
    repo.live.emit({'type': 'task.updated', 'task': taskJson(version: 2, status: 'awaiting_approval')});
    await Future<void>.delayed(Duration.zero);

    repo.nextCreated = CallTask.fromJson(taskJson(version: 1, status: 'planning'));
    await container.read(callsControllerProvider.notifier).create(
          const NewCallRequest(targetName: 'x', phoneNumber: '0212345678', goal: '예약 문의', language: CallLanguage.ko, requesterName: '김'),
        );

    expect(container.read(taskProvider('task-1'))?.status, TaskStatus.awaitingApproval);
  });

  test('stream deletions remove the task', () async {
    repo.live.emit({'type': 'task.updated', 'task': taskJson()});
    repo.live.emit({'type': 'task.deleted', 'taskId': 'task-1'});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(taskProvider('task-1')), isNull);
  });
}
