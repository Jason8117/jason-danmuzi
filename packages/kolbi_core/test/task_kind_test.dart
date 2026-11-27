// SPEC-SHELL-001 AC-007, AC-008 (functions): the task kind registry.
import 'package:kolbi_core/kolbi_core.dart';
import 'package:test/test.dart';

import 'support/tasks.dart';

void main() {
  test('registers call once and resolves call, null and unknown kinds', () {
    final catalog = TaskKindCatalog();
    expect(catalog.ids, isEmpty);

    catalog.register(const CallTaskKind());
    expect(catalog.ids, ['call']);
    expect(
      () => catalog.register(const CallTaskKind()),
      throwsA(isA<DuplicateTaskKindError>()),
    );

    expect(catalog.resolve('call'), isA<CallTaskKind>());
    expect(catalog.resolve(null), isA<CallTaskKind>());
    final unknown = catalog.resolve('web');
    expect(unknown, isA<UnknownTaskKind>());
    expect(unknown.id, 'web');
    expect(unknown.isKnown, isFalse);
    expect(catalog.resolve('call').isKnown, isTrue);
  });

  test(
    'a task without a kind reads as call; other values are kept as sent',
    () {
      expect(task().kind, isNull);
      expect(task(kind: 'web').kind, 'web');
      // A value of the wrong type never breaks parsing.
      expect(task(kind: 3).kind, isNull);

      final catalog = TaskKindCatalog()..register(const CallTaskKind());
      expect(catalog.resolveTask(task()).id, 'call');
      expect(catalog.resolveTask(task(kind: 'call')).id, 'call');
      expect(catalog.resolveTask(task(kind: 'web')).isKnown, isFalse);
    },
  );

  test('the call descriptor describes status and steps', () {
    const call = CallTaskKind();
    final live = task(approvals: [approval()]);
    expect(call.statusLabel(live), '승인 대기');
    expect(call.statusLabel(task(status: 'completed')), '완료');
    expect(
      call.steps(live).map((s) => s.state),
      taskSteps(live).map((s) => s.state),
    );
    expect(call.parseDetails(const {'anything': 1}), isNull);

    const unknown = UnknownTaskKind('web');
    expect(unknown.steps(live), isEmpty);
    expect(unknown.statusLabel(live), '알 수 없는 작업');
    expect(unknown.parseDetails(const {'a': 1}), {'a': 1});
  });
}
