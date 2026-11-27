// SPEC-SHELL-001 AC-011, AC-013, AC-014 (functions): design.md D3 and the Korean subject particle (D5).
import 'package:kolbi_core/kolbi_core.dart';
import 'package:test/test.dart';

import 'support/tasks.dart';

/// 2026-11-26 12:00 in Seoul.
final now = DateTime.utc(2026, 11, 26, 3);

/// The "섞음" set from acceptance.md.
List<CallTask> mixed() => [
  task(
    id: 'a',
    name: '라 파스타',
    approvals: [approval()],
    updatedAt: '2026-11-26T02:00:00Z',
  ),
  task(
    id: 'b',
    name: '우리동네 치과',
    status: 'awaiting_approval',
    transcript: false,
    updatedAt: '2026-11-26T02:30:00Z',
  ),
  task(id: 'c', name: '헤어살롱 봄', updatedAt: '2026-11-26T02:10:00Z'),
  task(
    id: 'd',
    name: '관리사무소',
    status: 'completed',
    outcome: outcome(),
    updatedAt: '2026-11-26T10:00:00+09:00',
  ),
  task(
    id: 'e',
    name: '행복 소아과',
    status: 'failed',
    transcript: false,
    updatedAt: '2026-11-25T18:00:00+09:00',
  ),
];

List<String> ids(Iterable<CallTask> tasks) => [for (final t in tasks) t.id];

void main() {
  test('tasks tab groups approvals, ongoing and routines', () {
    final groups = groupTasks(mixed(), now: now);
    expect(ids(groups.approvals), ['a', 'b']);
    expect(ids(groups.ongoing), ['c']);
    expect(groups.routines, isEmpty);
    expect(groups.completedToday, 1);
    expect(groups.badgeCount, 2);
    expect(groups.briefingCount, 3);

    // Expiry first (soonest first), then plan approvals by most recent update.
    final ordered = groupTasks([
      task(
        id: 'late',
        approvals: [approval(expiresIn: const Duration(seconds: 90))],
      ),
      task(
        id: 'plan-old',
        status: 'awaiting_approval',
        updatedAt: '2026-11-26T01:00:00Z',
      ),
      task(
        id: 'soon',
        approvals: [approval(expiresIn: const Duration(seconds: 10))],
      ),
      task(
        id: 'plan-new',
        status: 'awaiting_approval',
        updatedAt: '2026-11-26T02:00:00Z',
      ),
      task(id: 'on-old', status: 'dialing', updatedAt: '2026-11-26T01:00:00Z'),
      task(
        id: 'on-new',
        status: 'summarizing',
        updatedAt: '2026-11-26T02:00:00Z',
      ),
      task(id: 'p', status: 'planning', updatedAt: '2026-11-26T00:00:00Z'),
    ], now: now);
    expect(ids(ordered.approvals), ['soon', 'late', 'plan-new', 'plan-old']);
    expect(ids(ordered.ongoing), ['on-new', 'on-old', 'p']);

    // Finished tasks only: nothing to approve or follow.
    final finished = groupTasks(
      mixed().where((t) => t.status.isTerminal),
      now: now,
    );
    expect(finished.approvals, isEmpty);
    expect(finished.ongoing, isEmpty);
    expect(finished.badgeCount, 0);

    // A finished task with a leftover pending approval is not an approval request.
    final leftover = groupTasks([
      task(status: 'completed', approvals: [approval()]),
    ], now: now);
    expect(leftover.approvals, isEmpty);
    // "Today" is the Seoul day: 2026-11-26 00:30 Seoul counts, 2026-11-25 23:30 Seoul does not.
    final days = groupTasks([
      task(id: 'x', status: 'completed', updatedAt: '2026-11-25T15:30:00Z'),
      task(id: 'y', status: 'completed', updatedAt: '2026-11-25T14:30:00Z'),
      task(id: 'z', status: 'failed', updatedAt: '2026-11-26T01:00:00Z'),
    ], now: now);
    expect(days.completedToday, 1);
  });

  test('in-call approvals agree with pending approvals', () {
    final tasks = mixed();
    // Same rule as pendingApprovalsProvider (calls_controller.dart:115-120), minus finished tasks.
    final pendingProvider = {
      for (final t in tasks)
        if (t.pendingApproval != null) t.id,
    };
    final groups = groupTasks(tasks, now: now);
    expect(ids(groups.inCallApprovals).toSet(), pendingProvider);
    expect(ids(groups.inCallApprovals), ['a']);
  });

  test('history groups by Seoul date', () {
    final days = groupHistory(mixed(), now: now);
    expect(
      [for (final day in days) day.label],
      ['오늘 · 11월 26일', '어제 · 11월 25일'],
    );
    expect(
      [for (final day in days) ids(day.tasks)],
      [
        ['d'],
        ['e'],
      ],
    );

    // 23:59 and 00:01 Seoul fall on different days, whatever the device time zone.
    final edge = groupHistory([
      task(
        id: 'late',
        status: 'completed',
        updatedAt: '2026-11-25T23:59:00+09:00',
      ),
      task(
        id: 'early',
        status: 'canceled',
        updatedAt: '2026-11-26T00:01:00+09:00',
      ),
      task(id: 'old', status: 'failed', updatedAt: '2026-11-24T09:00:00+09:00'),
      task(
        id: 'older',
        status: 'completed',
        updatedAt: '2026-11-24T08:00:00+09:00',
      ),
      task(id: 'live', updatedAt: '2026-11-26T01:00:00Z'),
    ], now: now);
    expect(
      [for (final day in edge) day.label],
      ['오늘 · 11월 26일', '어제 · 11월 25일', '11월 24일'],
    );
    expect(
      [for (final day in edge) ids(day.tasks)],
      [
        ['early'],
        ['late'],
        ['old', 'older'],
      ],
    );
    expect(groupHistory([task()], now: now), isEmpty);
  });

  test('subject particle follows the final consonant', () {
    expect(withSubjectParticle('라 파스타'), '라 파스타가');
    expect(withSubjectParticle('우리동네 치과'), '우리동네 치과가');
    expect(withSubjectParticle('관리사무소'), '관리사무소가');
    expect(withSubjectParticle('헤어살롱 봄'), '헤어살롱 봄이');
    expect(withSubjectParticle('행복 소아과'), '행복 소아과가');
    expect(withSubjectParticle('ABC'), 'ABC(이)가');
    expect(withSubjectParticle(''), '');
  });
}
