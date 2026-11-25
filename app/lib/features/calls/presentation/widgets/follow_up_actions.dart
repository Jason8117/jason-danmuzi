import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/call_models.dart';
import '../../domain/follow_up.dart';
import '../../domain/intake_models.dart';

/// The one place the app reaches the clipboard and the share sheet, so widget tests can swap it (SPEC-FOLLOWUP-001 §4).
abstract interface class FollowUpService {
  Future<void> copyText(String text);
  Future<void> shareText(String text);
  Future<void> shareFile({required Uint8List bytes, required String name, required String mimeType});
}

/// Clipboard from the Flutter SDK, share sheet from `share_plus` (OD-1).
class DeviceFollowUpService implements FollowUpService {
  const DeviceFollowUpService();

  @override
  Future<void> copyText(String text) => Clipboard.setData(ClipboardData(text: text));

  // A dismissed or "unavailable" result is not treated as a failure: several platforms report "unavailable" even
  // after showing the sheet. Only a thrown error falls back to the clipboard.
  @override
  Future<void> shareText(String text) => SharePlus.instance.share(ShareParams(text: text));

  @override
  Future<void> shareFile({required Uint8List bytes, required String name, required String mimeType}) =>
      SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: mimeType, name: name)],
          fileNameOverrides: [name],
        ),
      );
}

final followUpServiceProvider = Provider<FollowUpService>((ref) => const DeviceFollowUpService());

/// `DTSTAMP` clock for the calendar draft; tests fix it.
final followUpClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// REQ-006: the actions of a finished call. "다시 걸기" always; copy and share with an outcome;
/// the calendar file only when [offersCalendarDraft] holds (REQ-010).
class FollowUpActions extends ConsumerStatefulWidget {
  const FollowUpActions({super.key, required this.task});

  final CallTask task;

  @override
  ConsumerState<FollowUpActions> createState() => _FollowUpActionsState();
}

class _FollowUpActionsState extends ConsumerState<FollowUpActions> {
  /// The action that is running; its button shows progress and the others wait (SPEC-UX-001 REQ-007).
  String? _busy;

  CallTask get task => widget.task;

  Future<void> _run(String action, Future<void> Function() run) async {
    if (_busy != null) return;
    setState(() => _busy = action);
    try {
      await run();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Widget _icon(String action, IconData icon) => _busy == action
      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
      : Icon(icon);

  @override
  Widget build(BuildContext context) {
    final outcome = task.outcome;
    final idle = _busy == null;
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      alignment: WrapAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => context.push('/plan', extra: PlanDraft.fromTask(task)),
          icon: const Icon(Icons.replay),
          label: const Text('다시 걸기'),
        ),
        if (outcome != null) ...[
          OutlinedButton.icon(
            onPressed: idle ? () => _run('copy', () => _copy(context)) : null,
            icon: _icon('copy', Icons.copy_rounded),
            label: const Text('요약 복사'),
          ),
          OutlinedButton.icon(
            onPressed: idle ? () => _run('share', () => _share(context)) : null,
            icon: _icon('share', Icons.ios_share_rounded),
            label: const Text('공유'),
          ),
        ],
        if (offersCalendarDraft(outcome))
          OutlinedButton.icon(
            onPressed: idle ? () => _run('calendar', () => _shareCalendar(context)) : null,
            icon: _icon('calendar', Icons.event_rounded),
            label: const Text('캘린더 파일 보내기'),
          ),
      ],
    );
  }

  /// Replaces a toast that is still showing, so the latest result is the one the user reads.
  void _notify(ScaffoldMessengerState messenger, String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(followUpServiceProvider).copyText(buildShareText(task));
    _notify(messenger, '요약을 복사했어요');
  }

  /// REQ-008: when sharing is unavailable or fails, the same text goes to the clipboard instead.
  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(followUpServiceProvider);
    final text = buildShareText(task);
    try {
      await service.shareText(text);
    } catch (_) {
      await service.copyText(text);
      _notify(messenger, '공유할 수 없어 복사했어요');
    }
  }

  /// REQ-012: the draft goes to the share sheet as `appointment.ics`; the app never writes to a calendar itself.
  Future<void> _shareCalendar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ics = buildCalendarDraft(task, now: ref.read(followUpClockProvider)());
    try {
      await ref
          .read(followUpServiceProvider)
          .shareFile(bytes: Uint8List.fromList(utf8.encode(ics)), name: 'appointment.ics', mimeType: 'text/calendar');
    } catch (_) {
      _notify(messenger, '캘린더 초안을 열 수 없어요');
    }
  }
}
