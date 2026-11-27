import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../shell/navigation.dart';
import '../application/calls_controller.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Surfaces a mid-call approval request wherever the user is in the app,
/// because the other party is on hold until they answer.
class ApprovalListener extends ConsumerStatefulWidget {
  const ApprovalListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ApprovalListener> createState() => _ApprovalListenerState();
}

class _ApprovalListenerState extends ConsumerState<ApprovalListener> {
  final _announced = <String>{};

  void _onPendingChanged(List<PendingApproval>? _, List<PendingApproval> next) {
    for (final (:task, :approval) in next) {
      if (!_announced.add(approval.id)) continue;

      final router = ref.read(routerProvider);
      if (router.state.uri.path == taskLocation(router, task.id)) continue;

      HapticFeedback.heavyImpact();
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          behavior: SnackBarBehavior.floating,
          content: Text('${task.targetName} 통화: ${approval.question}'),
          action: SnackBarAction(label: '답하기', onPressed: () => openTask(router, task.id)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingApprovalsProvider, _onPendingChanged);
    return widget.child;
  }
}
