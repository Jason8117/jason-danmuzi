import 'package:meta/meta.dart';

import 'call_models.dart';

/// Where the draft's number came from. Shown on the plan card so the user can judge it (SPEC-INTAKE-001 REQ-019).
enum PhoneSource {
  text('말씀하신 번호'),
  history('지난번 통화한 번호'),

  /// "다시 걸기": the number of the task being redialed. App-side only; the server never sends it (SPEC-FOLLOWUP-001).
  previousCall('지난번과 같은 번호');

  const PhoneSource(this.label);
  final String label;
}

/// How the server interpreted the request. Unknown values read as [heuristic], the less trusted one.
enum IntakeSource { llm, heuristic }

String? _string(Object? value) => value is String ? value : null;

List<String> _strings(Object? value) => value is List ? value.whereType<String>().toList(growable: false) : const [];

/// The plan-card draft: what `POST /v1/intake` proposed, before the user edits it.
@immutable
class PlanDraft {
  const PlanDraft({
    required this.goal,
    this.targetName,
    this.phoneNumber,
    this.conditions = const [],
    this.context,
    this.language = CallLanguage.ko,
    this.phoneSource,
    this.numberBlocked = false,
    this.source = IntakeSource.heuristic,
  });

  /// REQ-022: what an older server (404 on /v1/intake) gets — the request text as the goal and nothing else.
  factory PlanDraft.blank(String text) => PlanDraft(goal: text.trim());

  /// SPEC-FOLLOWUP-001 REQ-007: redial with the previous task's details; no intake request, no LLM.
  factory PlanDraft.fromTask(CallTask task) => PlanDraft(
        targetName: task.targetName,
        phoneNumber: task.phoneNumber,
        goal: task.goal,
        context: task.context,
        language: task.language,
        phoneSource: PhoneSource.previousCall,
      );

  final String? targetName;

  /// E.164, or null when the server found none.
  final String? phoneNumber;
  final String goal;
  final List<String> conditions;
  final String? context;
  final CallLanguage language;
  final PhoneSource? phoneSource;

  /// The request held only an emergency or special-service number.
  final bool numberBlocked;
  final IntakeSource source;
}

/// A parsed `POST /v1/intake` response. Parsing never throws on unknown or malformed values.
@immutable
class IntakeResult {
  const IntakeResult({required this.draft, this.missing = const []});

  factory IntakeResult.fromJson(Map<String, dynamic> json) {
    final draft = json['draft'] is Map ? (json['draft'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    return IntakeResult(
      draft: PlanDraft(
        targetName: _string(draft['targetName']),
        phoneNumber: _string(draft['phoneNumber']),
        goal: _string(draft['goal']) ?? '',
        conditions: _strings(draft['conditions']),
        context: _string(draft['context']),
        language: CallLanguage.parse(_string(draft['language'])),
        phoneSource: PhoneSource.values.where((s) => s.name == json['phoneSource']).firstOrNull,
        numberBlocked: json['numberIssue'] == 'blocked',
        source: json['source'] == 'llm' ? IntakeSource.llm : IntakeSource.heuristic,
      ),
      missing: _strings(json['missing']),
    );
  }

  final PlanDraft draft;
  final List<String> missing;
}

/// REQ-021: the goal sent to the server, with the conditions appended as `\n조건: a / b`.
String goalWithConditions(String goal, List<String> conditions) =>
    conditions.isEmpty ? goal : '$goal\n조건: ${conditions.join(' / ')}';
