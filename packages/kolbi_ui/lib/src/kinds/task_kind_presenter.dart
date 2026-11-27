import 'package:kolbi_core/kolbi_core.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../widgets/common.dart';

/// The screen half of a task kind (SPEC-SHELL-001 REQ-007, design.md D7): its icon, its list row and
/// its detail screen (which also shows the result).
abstract class TaskKindPresenter {
  const TaskKindPresenter();

  String get kindId;

  IconData get icon;

  /// One row in today, tasks or history. History passes its result chip as [trailing] and its result
  /// line as [subtitle].
  Widget buildRow(
    BuildContext context,
    CallTask task, {
    required VoidCallback onTap,
    Widget? trailing,
    String? subtitle,
  });

  /// The detail screen, which is also the result screen.
  Widget buildDetail(BuildContext context, String taskId);
}

/// Shown for a kind this app version does not know (REQ-008).
class UnknownKindPresenter extends TaskKindPresenter {
  const UnknownKindPresenter();

  @override
  String get kindId => 'unknown';

  @override
  IconData get icon => Icons.help_outline_rounded;

  @override
  Widget buildRow(
    BuildContext context,
    CallTask task, {
    required VoidCallback onTap,
    Widget? trailing,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Card(
        key: const Key('kind-unknown-row'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpace.md),
                const Expanded(child: Text('이 앱에서 아직 볼 수 없는 작업이에요')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildDetail(BuildContext context, String taskId) => Scaffold(
    appBar: AppBar(),
    body: const MessageView(
      icon: Icons.system_update_rounded,
      title: '이 작업은 앱을 업데이트하면 볼 수 있어요',
      message: '지금 앱 버전에서는 이 종류의 작업을 보여 드릴 수 없어요.',
    ),
  );
}

/// The presenter registry; a kind without a presenter falls back to [UnknownKindPresenter].
class TaskKindPresenters {
  final _presenters = <String, TaskKindPresenter>{};

  void register(TaskKindPresenter presenter) {
    if (_presenters.containsKey(presenter.kindId)) {
      throw DuplicateTaskKindError(presenter.kindId);
    }
    _presenters[presenter.kindId] = presenter;
  }

  TaskKindPresenter presenterFor(TaskKindDescriptor kind) =>
      (kind.isKnown ? _presenters[kind.id] : null) ??
      const UnknownKindPresenter();
}
