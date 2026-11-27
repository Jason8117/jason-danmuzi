import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolbi_core/kolbi_core.dart';

import '../../../core/config/app_settings.dart';

export 'package:kolbi_core/kolbi_core.dart' show CallsEvent, TasksSnapshot, TaskUpdated, TaskDeleted, CallsRepository;

final apiClientProvider = Provider<ApiClient>((ref) {
  final settings = ref.watch(settingsProvider);
  final client = ApiClient(baseUrl: settings.serverUrl, token: settings.apiToken);
  ref.onDispose(client.close);
  return client;
});

final callsRepositoryProvider = Provider<CallsRepository>((ref) => CallsRepository(ref.watch(apiClientProvider)));

final serverInfoProvider = FutureProvider<ServerInfo>((ref) => ref.watch(callsRepositoryProvider).serverInfo());
