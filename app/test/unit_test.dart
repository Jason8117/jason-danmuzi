import 'package:callmate/core/utils/formatters.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  group('formatPhone', () {
    test('formats Korean mobile numbers', () => expect(formatPhone('+821012345678'), '010-1234-5678'));
    test('formats Seoul landlines', () => expect(formatPhone('+8221234567'), '02-123-4567'));
    test('leaves foreign numbers alone', () => expect(formatPhone('+14155550100'), '+14155550100'));
  });

  test('formatDuration pads minutes and seconds', () {
    expect(formatDuration(const Duration(seconds: 75)), '01:15');
    expect(formatDuration(const Duration(hours: 1, seconds: 5)), '1:00:05');
  });

  group('CallTask.fromJson', () {
    test('maps wire status names and finds the pending approval', () {
      final task = CallTask.fromJson(taskJson(approvals: [approvalJson()]));
      expect(task.status, TaskStatus.inProgress);
      expect(task.status.isLiveCall, isTrue);
      expect(task.pendingApproval?.id, 'approval-1');
      expect(task.isSimulated, isTrue);
      expect(task.transcript.first.speaker, Speaker.callee);
    });

    test('parses outcomes', () {
      final task = CallTask.fromJson(taskJson(
        status: 'completed',
        outcome: {'result': 'partial', 'summary': '요약', 'keyFacts': ['7시 가능'], 'followUps': []},
      ));
      expect(task.status.isTerminal, isTrue);
      expect(task.outcome?.result, OutcomeResult.partial);
      expect(task.outcome?.keyFacts, ['7시 가능']);
    });

    // SPEC-OUTCOME-001 AC-009: new servers send "unverified" and a source; tasks saved earlier have neither.
    test('parses outcome result and source, old and new', () {
      CallOutcome? parse(Map<String, dynamic> outcome) =>
          CallTask.fromJson(taskJson(status: 'completed', outcome: outcome)).outcome;
      Map<String, dynamic> outcome(Map<String, dynamic> fields) =>
          {'summary': '요약', 'keyFacts': <String>[], 'followUps': <String>[], ...fields};

      final unverified = parse(outcome({'result': 'unverified', 'source': 'heuristic'}));
      expect(unverified?.result, OutcomeResult.unverified);
      expect(unverified?.source, OutcomeSource.heuristic);

      final llm = parse(outcome({'result': 'success', 'source': 'llm'}));
      expect(llm?.result, OutcomeResult.success);
      expect(llm?.source, OutcomeSource.llm);

      final legacy = parse(outcome({'result': 'partial'}));
      expect(legacy?.result, OutcomeResult.partial);
      expect(legacy?.source, OutcomeSource.unknown);

      final future = parse(outcome({'result': 'success', 'source': 'something_new'}));
      expect(future?.result, OutcomeResult.success);
      expect(future?.source, OutcomeSource.unknown);
    });

    // Guards SPEC-LIFECYCLE-001 REQ-011: the server adds an optional providerCallId; the app must not depend on it.
    test('ignores providerCallId when parsing tasks', () {
      final without = CallTask.fromJson(taskJson());
      final withId = CallTask.fromJson({...taskJson(), 'providerCallId': 'c-1'});
      expect(withId.id, without.id);
      expect(withId.status, without.status);
      expect(withId.isSimulated, without.isSimulated);
      expect(withId.transcript.length, without.transcript.length);
    });

    test('treats unknown statuses as failed instead of crashing', () {
      expect(TaskStatus.parse('something_new'), TaskStatus.failed);
    });
  });

  test('parses live stream events', () {
    expect(CallsRepository.parseEvent({'type': 'task.deleted', 'taskId': 'x'}), isA<TaskDeleted>());
    expect(CallsRepository.parseEvent({'type': 'task.updated', 'task': taskJson()}), isA<TaskUpdated>());
    expect(CallsRepository.parseEvent({'type': 'unknown'}), isNull);
  });
}
