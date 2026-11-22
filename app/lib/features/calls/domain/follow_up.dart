import 'dart:convert';

import 'package:intl/intl.dart';

import 'call_models.dart';

/// Asia/Seoul: a fixed +09:00 with no daylight saving time (SPEC-FOLLOWUP-001 REQ-009).
const seoulOffset = Duration(hours: 9);

/// Calendar default when the call confirmed no end time (OD-5).
const defaultAppointmentLength = Duration(minutes: 60);

const _unverifiedLine = '※ 자동 요약이라 목표를 이뤘는지 확인하지 못했어요.';
const _draftNote = 'AI 비서가 통화에서 확인한 내용으로 만든 초안이에요. 저장하기 전에 확인해 주세요.';

// @MX:NOTE: [AUTO] OD-4: the share text leaves the device, so it holds only the result label, the callee's name,
// the time, the summary and the two lists — never the number, transcript, approval comments or the requester's name.
/// REQ-009. The time is shown at [displayOffset] whatever the device's time zone is, so the result is deterministic.
/// Requires `task.outcome`; callers offer sharing only when there is one.
String buildShareText(CallTask task, {Duration displayOffset = seoulOffset}) {
  final outcome = task.outcome!;
  // Shifting a UTC instant and formatting its fields shows the wall-clock time at that offset.
  final shown = (task.endedAt ?? task.updatedAt).toUtc().add(displayOffset);
  final lines = [
    '[${outcome.result.label}] ${task.targetName} 통화 결과',
    DateFormat('y년 M월 d일 a h:mm', 'ko').format(shown),
    '',
    outcome.summary,
    if (outcome.result == OutcomeResult.unverified) _unverifiedLine,
    if (outcome.keyFacts.isNotEmpty) ...['', '알아낸 내용', for (final fact in outcome.keyFacts) '• $fact'],
    if (outcome.followUps.isNotEmpty) ...['', '해야 할 일', for (final item in outcome.followUps) '• $item'],
  ];
  return lines.join('\n');
}

/// REQ-010 (OD-2): only an LLM-checked success or partial result with a confirmed appointment.
bool offersCalendarDraft(CallOutcome? outcome) =>
    outcome != null &&
    outcome.source == OutcomeSource.llm &&
    (outcome.result == OutcomeResult.success || outcome.result == OutcomeResult.partial) &&
    outcome.appointment != null;

/// REQ-011: an RFC 5545 VCALENDAR with one VEVENT, CRLF line ends and 75-octet folding.
/// No attendee, organizer or phone number. Requires `task.outcome?.appointment`.
String buildCalendarDraft(CallTask task, {required DateTime now}) {
  final outcome = task.outcome!;
  final appointment = outcome.appointment!;
  final title = appointment.title.trim().isEmpty ? '${task.targetName} 일정' : appointment.title;
  final ends = appointment.endsAt ?? appointment.startsAt.add(defaultAppointmentLength);
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//CallMate//Follow-up//KO',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    'UID:${task.id}-appointment@callmate.local',
    'DTSTAMP:${_utcStamp(now)}',
    'DTSTART:${_utcStamp(appointment.startsAt)}',
    'DTEND:${_utcStamp(ends)}',
    'SUMMARY:${_escapeText(title)}',
    'DESCRIPTION:${_escapeText('${outcome.summary}\n\n$_draftNote')}',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return lines.map((line) => '${_fold(line)}\r\n').join();
}

String _two(int value) => value.toString().padLeft(2, '0');

/// `yyyyMMddTHHmmssZ` (UTC basic format).
String _utcStamp(DateTime time) {
  final t = time.toUtc();
  return '${t.year.toString().padLeft(4, '0')}${_two(t.month)}${_two(t.day)}'
      'T${_two(t.hour)}${_two(t.minute)}${_two(t.second)}Z';
}

/// RFC 5545 §3.3.11 TEXT escaping. The backslash goes first so the added ones are not doubled.
String _escapeText(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n');

/// RFC 5545 §3.1: lines longer than 75 octets continue on the next line after CRLF + one space.
/// Breaks only between characters, so a multi-byte UTF-8 character is never split.
String _fold(String line) {
  const limit = 75;
  final out = StringBuffer();
  var used = 0;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final size = utf8.encode(char).length;
    if (used + size > limit) {
      out.write('\r\n ');
      used = 1; // the leading space counts toward the next line's 75 octets
    }
    out.write(char);
    used += size;
  }
  return out.toString();
}
