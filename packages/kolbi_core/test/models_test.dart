// Package tests for kolbi_core (SPEC-MODULE-001 REQ-012, AC-010, AC-012).
import 'package:kolbi_core/kolbi_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'CallTask.fromJson reads an older task without outcome or approvals',
    () {
      final task = CallTask.fromJson({
        'id': 't1',
        'targetName': '동네 치과',
        'phoneNumber': '+821012345678',
        'goal': '예약 시간 확인',
        'language': 'ko',
        'status': 'completed',
      });

      expect(task.status, TaskStatus.completed);
      expect(task.approvals, isEmpty);
      expect(task.transcript, isEmpty);
      expect(task.outcome, isNull);
      expect(task.version, 0);
    },
  );

  test('approval comment helpers count code points and spot card numbers', () {
    expect(truncateToCodePoints('가나다', 2), '가나');
    expect(hasSensitiveDigits('카드 1234 5678 9012 3456'), isTrue);
    expect(codePointLength('가나다'), 3);
  });
}
