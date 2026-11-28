import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../features/calls/data/calls_repository.dart';
import '../features/calls/presentation/call_templates.dart';
import 'task_feed.dart';

// SPEC-ASSIST-001: the assistant's request box needs the call feature's intake, templates and recent places.
// Features never import each other (SPEC-SHELL-001 REQ-018), so the shell hands them over, as task_feed does.

/// The request templates ("이런 부탁도 할 수 있어요"), in display order.
final requestTemplatesProvider = Provider<List<CallTemplate>>(
  (ref) => callTemplates,
);

/// "최근 장소"; null while the task list loads or after it failed (the group is then hidden).
final recentPlacesProvider = Provider<List<Counterparty>?>(
  (ref) => switch (ref.watch(taskListProvider)) {
    AsyncData(:final value) => recentCounterparties(value),
    _ => null,
  },
);

/// Sends a one-line request to `POST /v1/intake` (SPEC-INTAKE-001 REQ-017). A server without the endpoint
/// gets a blank draft with nothing missing (REQ-022), so it goes to the plan card; any other failure shows a
/// snack bar and returns null. The whole result is returned because `missing` decides whether place
/// selection opens (SPEC-PLACE-001 REQ-009).
Future<IntakeResult?> requestIntake(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  String text,
) async {
  try {
    // The input has no language picker; the plan card can switch the call language.
    return await ref
        .read(callsRepositoryProvider)
        .intake(text, CallLanguage.ko);
  } on ApiException catch (error) {
    if (error.statusCode == 404) {
      return IntakeResult(draft: PlanDraft.blank(text));
    }
    messenger.showSnackBar(SnackBar(content: Text(describeError(error))));
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(describeError(error))));
  }
  return null;
}
