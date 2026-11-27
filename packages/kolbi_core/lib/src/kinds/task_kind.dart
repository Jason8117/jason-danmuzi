import '../models/call_models.dart';
import '../tasks/task_steps.dart';

/// The headless half of a task kind (SPEC-SHELL-001 REQ-007, design.md D7): its id, status wording,
/// how its kind-specific details are read, and its steps. The screen half lives in kolbi_ui.
abstract interface class TaskKindDescriptor {
  String get id;

  /// False only for the stand-in returned for a kind this app does not know.
  bool get isKnown;

  String statusLabel(CallTask task);

  /// Reads the kind-specific part of a task; null when the kind has none.
  Object? parseDetails(Map<String, dynamic> json);

  List<TaskStep> steps(CallTask task);
}

/// The id a task without a `kind` value reads as.
const kCallKindId = 'call';

/// Thrown when a kind id is registered twice.
class DuplicateTaskKindError extends StateError {
  DuplicateTaskKindError(String id)
    : super('task kind "$id" is already registered');
}

/// A kind value this app version does not know (REQ-008). It never throws.
class UnknownTaskKind implements TaskKindDescriptor {
  const UnknownTaskKind(this.id);

  @override
  final String id;

  @override
  bool get isKnown => false;

  @override
  String statusLabel(CallTask task) => '알 수 없는 작업';

  @override
  Object? parseDetails(Map<String, dynamic> json) => json;

  @override
  List<TaskStep> steps(CallTask task) => const [];
}

/// The task kind registry.
class TaskKindCatalog {
  final _kinds = <String, TaskKindDescriptor>{};

  List<String> get ids => List.unmodifiable(_kinds.keys);

  void register(TaskKindDescriptor kind) {
    if (_kinds.containsKey(kind.id)) throw DuplicateTaskKindError(kind.id);
    _kinds[kind.id] = kind;
  }

  /// A missing value reads as `call`; an unregistered one gets an [UnknownTaskKind].
  TaskKindDescriptor resolve(String? kind) {
    final id = kind ?? kCallKindId;
    return _kinds[id] ?? UnknownTaskKind(id);
  }

  TaskKindDescriptor resolveTask(CallTask task) => resolve(task.kind);
}
