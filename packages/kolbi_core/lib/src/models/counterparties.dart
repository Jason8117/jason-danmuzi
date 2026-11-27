import 'package:meta/meta.dart';

import 'call_models.dart';

/// Lower-cased with every whitespace removed. The server uses the same rule and vectors
/// (`server/src/domain/intake.ts`, SPEC-INTAKE-001 design.md §3.1). No Unicode normalization.
String normalizeName(String name) => name.toLowerCase().replaceAll(RegExp(r'\s'), '');

/// Someone the user called before, computed from the stored tasks each time (nothing is saved).
@immutable
class Counterparty {
  const Counterparty({required this.name, required this.phoneNumber, required this.callCount});

  /// The spelling of the most recent call.
  final String name;

  /// E.164, exactly as stored.
  final String phoneNumber;
  final int callCount;
}

/// REQ-018 (a), OD-5: finished calls whose callee answered, grouped by normalized name and number,
/// most recent first, at most [limit]. Calls still in progress or planning never appear here.
List<Counterparty> recentCounterparties(Iterable<CallTask> tasks, {int limit = 3}) {
  final answered = tasks.where((t) => t.status.isTerminal && t.connectedAt != null).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final groups = <(String, String), List<CallTask>>{};
  for (final task in answered) {
    groups.putIfAbsent((normalizeName(task.targetName), task.phoneNumber), () => []).add(task);
  }
  return [
    for (final calls in groups.values.take(limit))
      Counterparty(name: calls.first.targetName, phoneNumber: calls.first.phoneNumber, callCount: calls.length),
  ];
}
