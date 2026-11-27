import 'package:go_router/go_router.dart';
import 'package:kolbi_core/kolbi_core.dart';

import 'routes.dart';

// SPEC-SHELL-001 design.md D1.2: the only place moves between tabs are written. Features call these four
// functions and named routes; they never call `go`, `goNamed` or `goBranch` themselves (AC-018).

final _shells = Expando<StatefulNavigationShell>('tab shell');

/// Called by the tab scaffold on every build, so [openTab] switches branches the way a tab tap does.
void registerTabShell(GoRouter router, StatefulNavigationShell shell) =>
    _shells[router] = shell;

// @MX:ANCHOR: [AUTO] Every "open this task" path (rows, plan card, manual form, approval snack bar) lands here.
// @MX:REASON: Closing every pushed screen before go+push is what keeps a plan card from staying on today (research R1 X1, Y1-Y3).
// @MX:SPEC: SPEC-SHELL-001 REQ-005
/// Closes every pushed screen (the assistant included), selects the tasks tab and opens [taskId] on top of
/// its first screen, so back returns to the tasks list.
void openTask(GoRouter router, String taskId) {
  // Bounded: a pop that does not take effect must never spin forever.
  for (var i = 0; i < 32 && router.canPop(); i++) {
    router.pop();
  }
  router.goNamed(RouteNames.inbox);
  router.pushNamed(RouteNames.task, pathParameters: {'id': taskId});
}

/// Selects [tab] keeping the screens stacked on it, like tapping it in the tab bar.
void openTab(GoRouter router, AppTab tab) {
  final shell = _shells[router];
  if (shell != null) {
    shell.goBranch(tab.index);
  } else {
    router.go(tab.path);
  }
}

/// Opens the assistant over the current tab; closing it returns to the same tab and screen.
void openAssistant(GoRouter router) => router.pushNamed(RouteNames.assistant);

/// From the assistant to the plan card: close the assistant first, because pushing a tab screen over a
/// route outside the shell asserts in go_router 18 (research R1-G, G2).
void submitFromAssistant(GoRouter router, PlanDraft draft) {
  if (router.canPop()) router.pop();
  router.pushNamed(RouteNames.plan, extra: draft);
}

/// The detail location of [taskId], for comparisons with the current location.
String taskLocation(GoRouter router, String taskId) =>
    router.namedLocation(RouteNames.task, pathParameters: {'id': taskId});
