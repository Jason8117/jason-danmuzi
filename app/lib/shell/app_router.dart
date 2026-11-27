import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_core/kolbi_core.dart';

import '../features/calls/presentation/call_templates.dart';
import '../features/calls/presentation/home_screen.dart';
import '../features/calls/presentation/new_call_screen.dart';
import '../features/calls/presentation/plan_card_screen.dart';
import '../features/history/history_screen.dart';
import '../features/inbox/inbox_screen.dart';
import '../features/me/me_screen.dart';
import '../features/settings/settings_screen.dart';
import 'assistant_placeholder.dart';
import 'kind_registration.dart';
import 'routes.dart';
import 'tab_scaffold.dart';

// @MX:ANCHOR: [AUTO] The app's only GoRouter: four tab branches and /assistant outside the shell (design.md D1.1).
// @MX:REASON: The tab-switching rules in navigation.dart rely on this layout (research R1); AC-018 pins it to the shell.
// @MX:SPEC: SPEC-SHELL-001 REQ-004
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            TabScaffold(navigationShell: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) =>
            BranchStack(
              currentIndex: navigationShell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: RouteNames.today,
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(
                path: '/calls/new',
                name: RouteNames.newCall,
                builder: (context, state) => NewCallScreen(
                  template: state.extra is CallTemplate
                      ? state.extra! as CallTemplate
                      : null,
                  redial: state.extra is CallTask
                      ? state.extra! as CallTask
                      : null,
                ),
              ),
              // SPEC-INTAKE-001: the plan card needs a draft; without one there is nothing to show, so go home.
              GoRoute(
                path: '/plan',
                name: RouteNames.plan,
                redirect: (context, state) =>
                    state.extra is PlanDraft ? null : '/',
                builder: (context, state) =>
                    PlanCardScreen(draft: state.extra! as PlanDraft),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inbox',
                name: RouteNames.inbox,
                builder: (context, state) => const InboxScreen(),
              ),
              GoRoute(
                path: '/calls/:id',
                name: RouteNames.task,
                builder: (context, state) =>
                    TaskDetailRoute(taskId: state.pathParameters['id']!),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                name: RouteNames.history,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                name: RouteNames.me,
                builder: (context, state) => const MeScreen(),
              ),
              GoRoute(
                path: '/settings',
                name: RouteNames.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/assistant',
        name: RouteNames.assistant,
        builder: (context, state) => const AssistantPlaceholderScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
