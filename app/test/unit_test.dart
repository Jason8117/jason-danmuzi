import 'package:callmate/core/utils/formatters.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/approval_comment.dart';
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

    // SPEC-ARCH-001 AC-014 (OD-1 DEFAULT): a provider the app does not know is shown as a real call.
    test('treats unknown providers as real calls', () {
      final task = CallTask.fromJson({...taskJson(), 'provider': 'telco_x'});
      expect(task.id, 'task-1');
      expect(task.isSimulated, isFalse);
      expect(CallTask.fromJson({...taskJson(), 'provider': 'kat'}).isSimulated, isFalse);
      expect(CallTask.fromJson(taskJson()).isSimulated, isTrue);
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

  group('approval comment rules (SPEC-APPROVAL-001)', () {
    // AC-003 vector table: the same 16 rows as server/src/domain/approvalComment.test.ts.
    // true = the server masks something in this input, so the app shows its warning.
    const vectors = <(String, bool)>[
      ('카드 1234-5678-9012-3456로 결제', true),
      ('주민번호 900101-1234567', true),
      ('1234 5678 9012 345 입니다', true),
      ('4111111111111111', true),
      ('010-1234-5678로 연락 주세요', false),
      ('주문 2024-1234-5678', false),
      ('12345678901234567890', true),
      ('1234--5678-9012-3456', false),
      ('카드 1111 2222 3333 4444, 다른 카드 5555-6666-7777-8888', true),
      ('010-1234-5678 010-9876-5432', false),
      ('1234 5678 9012 3456 7890', true),
      ('카드 1234-5678-9012-3456 0101', true),
      ('카드 1234 5678 9012 3456 1225 123', true),
      ('주민번호 900101-1234567 010-1234-5678', true),
      ('010-1234-5678 1234 5678 9012 3456', true),
      ('01012345678 01098765432', true),
    ];

    test('detects sensitive digit runs like the server', () {
      expect(vectors, hasLength(16));
      for (final (input, masked) in vectors) {
        expect(hasSensitiveDigits(input), masked, reason: input);
      }
      // The server turns a tab into a space and drops control characters before it looks for digits.
      expect(hasSensitiveDigits('1234\t5678\t9012\t3456'), isTrue);
      expect(hasSensitiveDigits('1234\u00005678\u00009012\u00003456'), isTrue);
    });

    test('counts and truncates in code points without splitting a character', () {
      const family = '👨‍👩‍👧';
      expect(codePointLength(family), 5);
      expect(codePointLength(truncateToCodePoints('가' * 501, kMaxApprovalCommentCodePoints)), 500);
      expect(truncateToCodePoints(family * 101, kMaxApprovalCommentCodePoints), family * 100);
      expect(truncateToCodePoints('a$family', 3), 'a');
      expect(truncateToCodePoints('짧은 글', 500), '짧은 글');
    });

    test('adds a quick reply once, separated by one space', () {
      expect(kApprovalQuickReplies, hasLength(3));
      expect(withQuickReply('', '다음 주로'), '다음 주로');
      expect(withQuickReply('1만 원까지만 ', '다음 주로'), '1만 원까지만 다음 주로');
      expect(withQuickReply('1만 원까지만 다음 주로', '다음 주로'), '1만 원까지만 다음 주로');
      expect(withQuickReply('가' * 499, '다음 주로'), '가' * 499);
    });
  });
}
