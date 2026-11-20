import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` once SharedPreferences has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

@immutable
class AppSettings {
  const AppSettings({
    required this.serverUrl,
    this.apiToken = '',
    this.requesterName = '',
    this.callbackNumber = '',
  });

  final String serverUrl;
  final String apiToken;
  final String requesterName;
  final String callbackNumber;

  bool get hasProfile => requesterName.trim().isNotEmpty;

  AppSettings copyWith({
    String? serverUrl,
    String? apiToken,
    String? requesterName,
    String? callbackNumber,
  }) {
    return AppSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      apiToken: apiToken ?? this.apiToken,
      requesterName: requesterName ?? this.requesterName,
      callbackNumber: callbackNumber ?? this.callbackNumber,
    );
  }

  /// The Android emulator reaches the host machine through 10.0.2.2, not localhost.
  static String get defaultServerUrl {
    const fromBuild = String.fromEnvironment('CALLMATE_SERVER_URL');
    if (fromBuild.isNotEmpty) return fromBuild;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8787';
    }
    return 'http://127.0.0.1:8787';
  }
}

class SettingsController extends Notifier<AppSettings> {
  static const _serverUrl = 'serverUrl';
  static const _apiToken = 'apiToken';
  static const _requesterName = 'requesterName';
  static const _callbackNumber = 'callbackNumber';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      serverUrl: prefs.getString(_serverUrl) ?? AppSettings.defaultServerUrl,
      apiToken: prefs.getString(_apiToken) ?? const String.fromEnvironment('CALLMATE_API_TOKEN'),
      requesterName: prefs.getString(_requesterName) ?? '',
      callbackNumber: prefs.getString(_callbackNumber) ?? '',
    );
  }

  Future<void> save(AppSettings settings) async {
    final normalized = settings.copyWith(
      serverUrl: settings.serverUrl.trim().replaceAll(RegExp(r'/+$'), ''),
      apiToken: settings.apiToken.trim(),
      requesterName: settings.requesterName.trim(),
      callbackNumber: settings.callbackNumber.trim(),
    );
    await Future.wait([
      _prefs.setString(_serverUrl, normalized.serverUrl),
      _prefs.setString(_apiToken, normalized.apiToken),
      _prefs.setString(_requesterName, normalized.requesterName),
      _prefs.setString(_callbackNumber, normalized.callbackNumber),
    ]);
    state = normalized;
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
