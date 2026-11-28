// SPEC-SHELL-001 AC-015, AC-016 (today, design.md D5) and the tonal [내 정보 입력] button.
import 'dart:ui' show Tristate;

import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'support/shell_support.dart';

Finder inToday(Finder finder) =>
    find.descendant(of: find.byKey(todayScreen), matching: finder);

/// The mixed set plus a finished, connected call, so "최근 통화한 곳" has an entry.
List<CallTask> withRecentPlace() => [
  ...mixedTasks(),
  shellTask(
    'f',
    '동네 세탁소',
    status: 'completed',
    outcome: successOutcome(),
    updatedAt: '2026-11-24T10:00:00+09:00',
  ),
];

const profile = {'requesterName': '지은', 'trustNoticeAcknowledged': true};

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  testWidgets('today follows the dashboard order', (tester) async {
    // (1)
    await pumpShell(tester, tasks: withRecentPlace(), prefs: profile);
    final order = [
      find.text('kolbi.'),
      find.text('11월 26일 목요일'),
      find.text('좋은 오후예요, 지은 님.'),
      find.text('오늘도 제가 함께할게요.'),
      find.text('오늘 중요한 일이 3개 있어요.'),
      find.text('라 파스타가 답을 기다려요.'),
      find.text('전화 대신하기'),
      find.text('확인이 필요해요'),
      find.text('진행 중'),
      find.text('최근 통화한 곳'),
    ];
    final tops = [
      for (final f in order) tester.getTopLeft(inToday(f).first).dy,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: 'item $i');
    }
    expect(
      tester.widget<Text>(find.byKey(const Key('today-approvals-count'))).data,
      '2',
    );
    expect(find.text('지난 통화'), findsNothing);
    expect(find.text('CallMate'), findsNothing);
    // First two of each list only: a and b need a decision, c is on a call; d, e and f are finished.
    expect(inToday(find.text('관리사무소')), findsNothing);
    expect(find.byTooltip('설정'), findsOneWidget);

    // (2) no tasks: the briefing's empty wording (SPEC-ASSIST-001 REQ-010)
    await pumpShell(tester, prefs: profile);
    expect(find.text('오늘은 맡긴 일이 없어요.'), findsOneWidget);
    expect(find.text('가운데 버튼으로 부탁해 보세요.'), findsOneWidget);
    for (final text in ['확인이 필요해요', '진행 중']) {
      expect(inToday(find.text(text)), findsNothing, reason: text);
    }
    expect(find.byTooltip('설정'), findsOneWidget);
  });

  testWidgets('greeting follows the time of day', (tester) async {
    for (final (hour, greeting) in [
      (9, '좋은 아침이에요'),
      (14, '좋은 오후예요'),
      (21, '좋은 저녁이에요'),
    ]) {
      // Seoul hour → UTC
      await pumpShell(
        tester,
        tasks: mixedTasks(),
        prefs: profile,
        now: DateTime.utc(2026, 11, 26, hour - 9),
      );
      expect(
        find.textContaining(RegExp('^$greeting')),
        findsOneWidget,
        reason: '$hour',
      );
    }
    // Without a name the greeting ends after the time of day.
    await pumpShell(
      tester,
      tasks: mixedTasks(),
      prefs: const {'trustNoticeAcknowledged': true},
    );
    expect(find.text('좋은 오후예요.'), findsOneWidget);
  });

  testWidgets('today shortcuts', (tester) async {
    final handle = tester.ensureSemantics();
    // (1), (2) open the assistant
    for (final key in ['shortcut-call', 'shortcut-search']) {
      await pumpShell(tester, tasks: mixedTasks());
      await tapAndSettle(tester, find.byKey(Key(key)));
      expect(
        find.byKey(const Key('assistant-intake-field')),
        findsOneWidget,
        reason: key,
      );
    }

    // (3) disabled: nothing happens
    await pumpShell(tester, tasks: mixedTasks());
    for (final key in ['shortcut-calendar', 'shortcut-mail']) {
      final node = tester.getSemantics(find.byKey(Key(key)));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse, reason: key);
      expect(node.label, contains('곧 쓸 수 있어요'), reason: key);
    }
    await tester.tap(
      find.byKey(const Key('shortcut-calendar')),
      warnIfMissed: false,
    );
    await settle(tester);
    expect(find.byKey(todayScreen), findsOneWidget);
    expect(find.byKey(const Key('assistant-intake-field')), findsNothing);

    // (4) the briefing link selects the tasks tab
    await pumpShell(tester, tasks: mixedTasks());
    await tapAndSettle(tester, find.text('업무 보기 →'));
    expect(isSelected(tester, tabTasks), isTrue);
    handle.dispose();
  });

  testWidgets('the profile prompt uses the tonal colors', (tester) async {
    final handle = tester.ensureSemantics();
    for (final dark in [false, true]) {
      await pumpShell(
        tester,
        tasks: mixedTasks(),
        prefs: const {'trustNoticeAcknowledged': true},
        dark: dark,
      );
      final button = find.ancestor(
        of: find.text('내 정보 입력'),
        matching: find.byType(FilledButton),
      );
      final style = tester.widget<FilledButton>(button).style!;
      final scheme = Theme.of(tester.element(button)).colorScheme;
      expect(
        style.backgroundColor?.resolve({}),
        scheme.primaryContainer,
        reason: 'dark=$dark',
      );
      expect(
        style.foregroundColor?.resolve({}),
        scheme.onPrimaryContainer,
        reason: 'dark=$dark',
      );
      await expectLater(
        tester,
        meetsGuideline(textContrastGuideline),
        reason: 'dark=$dark',
      );
    }
    handle.dispose();
  });
}
