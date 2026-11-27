import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_core/kolbi_core.dart';

import '../features/assistant/assistant_screen.dart';
import '../features/calls/presentation/call_templates.dart';
import '../features/calls/presentation/home_screen.dart';
import '../features/calls/presentation/live_call_screen.dart';
import '../features/calls/presentation/new_call_screen.dart';
import '../features/calls/presentation/plan_card_screen.dart';
import '../features/history/history_screen.dart';
import '../features/inbox/inbox_screen.dart';
import '../features/me/me_screen.dart';
import '../features/settings/settings_screen.dart';
import 'kind_registration.dart';
import 'routes.dart';
import 'tab_scaffold.dart';

// @MX:ANCHOR: [AUTO] The app's only GoRouter: four tab branches, /assistant (with its child routes) outside the shell (design.md D1.1).
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
      // SPEC-ASSIST-001 REQ-011: the live call screen covers the tab bar; it is pushed over the task screen.
      GoRoute(
        path: '/calls/:id/live',
        name: RouteNames.liveCall,
        builder: (context, state) =>
            LiveCallScreen(taskId: state.pathParameters['id']!),
      ),
      // SPEC-ASSIST-001 REQ-009: what the assistant opens are its child routes, never tab routes pushed over
      // it (research R1-G3); the same screen widgets as their tab routes.
      GoRoute(
        path: '/assistant',
        name: RouteNames.assistant,
        builder: (context, state) => AssistantScreen(
          textMode: state.uri.queryParameters['mode'] == 'text',
          fill: state.extra is String ? state.extra! as String : null,
        ),
        routes: [
          GoRoute(
            path: 'plan',
            name: RouteNames.assistantPlan,
            redirect: (context, state) =>
                state.extra is PlanDraft ? null : '/assistant',
            builder: (context, state) =>
                PlanCardScreen(draft: state.extra! as PlanDraft),
          ),
          GoRoute(
            path: 'settings',
            name: RouteNames.assistantSettings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'new',
            name: RouteNames.assistantNew,
            builder: (context, state) => const NewCallScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
