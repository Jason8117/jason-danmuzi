import 'package:intl/intl.dart';

final _representative = RegExp(r'^\+1([568]\d{6})$');

/// Shows Korean E.164 numbers in the familiar local form (+821012345678 → 010-1234-5678).
/// The server reads representative numbers (1588-0000) as `+1` plus seven digits; they are shown as dialed
/// (SPEC-PLACE-001 design.md D9). North American numbers have ten digits after `+1` and stay as they are.
String formatPhone(String e164) {
  final representative = _representative.firstMatch(e164)?.group(1);
  if (representative != null) {
    return '1${representative.substring(0, 3)}-${representative.substring(3)}';
  }
  if (!e164.startsWith('+82')) return e164;
  final national = '0${e164.substring(3)}';
  if (national.startsWith('02') && national.length >= 9) {
    final mid = national.length == 9 ? 3 : 4;
    return '02-${national.substring(2, 2 + mid)}-${national.substring(2 + mid)}';
  }
  if (national.length == 11) {
    return '${national.substring(0, 3)}-${national.substring(3, 7)}-${national.substring(7)}';
  }
  if (national.length == 10) {
    return '${national.substring(0, 3)}-${national.substring(3, 6)}-${national.substring(6)}';
  }
  return national;
}

String formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$minutes:$seconds' : '$minutes:$seconds';
}

String formatRelative(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(time);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1 && reference.day == time.day) return DateFormat('a h:mm', 'ko').format(time);
  if (diff.inDays < 7) return DateFormat('E a h:mm', 'ko').format(time);
  return DateFormat('M월 d일', 'ko').format(time);
}

String formatClock(DateTime time) => DateFormat('a h:mm:ss', 'ko').format(time);
