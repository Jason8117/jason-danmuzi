import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calls/domain/call_models.dart';
import '../../features/calls/domain/intake_models.dart';
import '../../features/calls/presentation/call_detail_screen.dart';
import '../../features/calls/presentation/call_templates.dart';
import '../../features/calls/presentation/home_screen.dart';
import '../../features/calls/presentation/new_call_screen.dart';
import '../../features/calls/presentation/plan_card_screen.dart';
import '../../features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/calls/new',
        builder: (context, state) => NewCallScreen(
          template: state.extra is CallTemplate ? state.extra! as CallTemplate : null,
          redial: state.extra is CallTask ? state.extra! as CallTask : null,
        ),
      ),
      // SPEC-INTAKE-001: the plan card needs a draft; without one there is nothing to show, so go home.
      GoRoute(
        path: '/plan',
        redirect: (context, state) => state.extra is PlanDraft ? null : '/',
        builder: (context, state) => PlanCardScreen(draft: state.extra! as PlanDraft),
      ),
      GoRoute(
        path: '/calls/:id',
        builder: (context, state) => CallDetailScreen(taskId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
