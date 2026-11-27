import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'core/router/app_router.dart';
import 'features/calls/presentation/approval_listener.dart';

class CallMateApp extends ConsumerWidget {
  const CallMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CallMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: scaffoldMessengerKey,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => ApprovalListener(child: child ?? const SizedBox.shrink()),
    );
  }
}
