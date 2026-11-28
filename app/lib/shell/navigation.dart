import 'package:go_router/go_router.dart';
import 'package:kolbi_core/kolbi_core.dart';

import 'routes.dart';

// SPEC-SHELL-001 design.md D1.2: the only place moves between tabs are written. Features call these
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

/// Opens the assistant over the current tab; closing it returns to the same tab and screen. [text] opens it
/// in text mode, [fill] puts a request start in its input (SPEC-ASSIST-001 REQ-008, REQ-010).
void openAssistant(GoRouter router, {bool text = false, String? fill}) =>
    router.pushNamed(
      RouteNames.assistant,
      queryParameters: text || fill != null ? const {'mode': 'text'} : const {},
      extra: fill,
    );

/// Closes the assistant. Opened as the first route (a web deep link) there is nothing underneath, so it goes
/// to today instead of popping (SHELL-001 sync-audit F1).
void closeAssistant(GoRouter router) {
  if (router.canPop()) {
    router.pop();
  } else {
    router.goNamed(RouteNames.today);
  }
}

// The assistant sits outside the tab shell, and a tab screen pushed over it asserts in go_router 18
// (research R1-G). Everything the assistant opens is therefore one of its child routes (R1-G3).

/// The plan card over the assistant; back returns to the assistant with its input.
void openAssistantPlan(GoRouter router, PlanDraft draft) =>
    router.pushNamed(RouteNames.assistantPlan, extra: draft);

/// Settings over the assistant (the request needs the requester's name).
void openAssistantSettings(GoRouter router) =>
    router.pushNamed(RouteNames.assistantSettings);

/// The manual form over the assistant.
void openAssistantManual(GoRouter router) =>
    router.pushNamed(RouteNames.assistantNew);

/// Settings from a screen that may sit over the assistant (the plan card): the assistant's child route there,
/// the tab route elsewhere.
void openSettings(GoRouter router) => router.pushNamed(
  router.state.uri.path.startsWith(router.namedLocation(RouteNames.assistant))
      ? RouteNames.assistantSettings
      : RouteNames.settings,
);

/// The live call screen over the task screen (SPEC-ASSIST-001 REQ-012).
void openLiveCall(GoRouter router, String taskId) =>
    router.pushNamed(RouteNames.liveCall, pathParameters: {'id': taskId});

/// The call ended: back to the task screen underneath (a pop, so it is not stacked twice); opened as the
/// first route there is none, so the task opens on the tasks tab instead.
void closeLiveCall(GoRouter router, String taskId) {
  if (router.canPop()) {
    router.pop();
  } else {
    openTask(router, taskId);
  }
}

/// The live call location of [taskId] (the approval alert stays quiet there too).
String liveCallLocation(GoRouter router, String taskId) =>
    router.namedLocation(RouteNames.liveCall, pathParameters: {'id': taskId});

/// The detail location of [taskId], for comparisons with the current location.
String taskLocation(GoRouter router, String taskId) =>
    router.namedLocation(RouteNames.task, pathParameters: {'id': taskId});
