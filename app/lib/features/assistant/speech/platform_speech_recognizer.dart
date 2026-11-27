import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_recognizer.dart';

/// [SpeechRecognizer] over `speech_to_text` (listening) and `permission_handler` (the four permission
/// states and the settings link, which `speech_to_text` does not offer — plan-audit D5).
///
/// A platform without the plugins (widget tests, unsupported desktops) throws [MissingPluginException] on
/// the first call; that is reported as [MicPermission.unavailable] so the assistant opens in text mode.
class PlatformSpeechRecognizer implements SpeechRecognizer {
  PlatformSpeechRecognizer({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool? _initialized;
  StreamController<SpeechEvent>? _session;
  bool _sessionOnDevice = false;
  bool _gotFinal = false;

  static const _permissions = [ph.Permission.microphone, ph.Permission.speech];

  static MicPermission _combine(
    Iterable<ph.PermissionStatus> statuses, {
    required bool asked,
  }) {
    if (statuses.any((s) => s.isPermanentlyDenied || s.isRestricted)) {
      return MicPermission.permanentlyDenied;
    }
    if (statuses.every((s) => s.isGranted || s.isLimited)) {
      return MicPermission.granted;
    }
    // Before a request `denied` means "not asked yet" on iOS and "may ask again" on Android.
    return asked ? MicPermission.denied : MicPermission.notDetermined;
  }

  @override
  Future<MicPermission> permission() async {
    try {
      final statuses = [for (final p in _permissions) await p.status];
      return _combine(statuses, asked: false);
    } on MissingPluginException {
      return MicPermission.unavailable;
    } on PlatformException {
      return MicPermission.unavailable;
    }
  }

  @override
  Future<MicPermission> requestPermission() async {
    try {
      final result = await _permissions.request();
      return _combine(result.values, asked: true);
    } on MissingPluginException {
      return MicPermission.unavailable;
    } on PlatformException {
      return MicPermission.unavailable;
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await ph.openAppSettings();
    } on MissingPluginException {
      // Nothing to open on this platform.
    }
  }

  /// Initializes only after the permissions are granted: `initialize` itself would raise the OS dialog.
  Future<bool> _ensureInitialized() async {
    if (_initialized case final done?) return done;
    try {
      _initialized = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
    } on MissingPluginException {
      _initialized = false;
    } on PlatformException {
      _initialized = false;
    }
    return _initialized!;
  }

  @override
  Future<String?> koreanLocaleId() async {
    if (!await _ensureInitialized()) return null;
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        if (RegExp(
          r'^ko([-_]|$)',
          caseSensitive: false,
        ).hasMatch(locale.localeId)) {
          return locale.localeId;
        }
      }
    } on PlatformException {
      return null;
    }
    return null;
  }

  @override
  Stream<SpeechEvent> listen({
    required String localeId,
    required bool onDevice,
    bool partialResults = true,
  }) {
    _closeSession();
    final session = _session = StreamController<SpeechEvent>();
    _sessionOnDevice = onDevice;
    _gotFinal = false;
    () async {
      if (!await _ensureInitialized()) {
        _emit(const SpeechError('unavailable'), close: true);
        return;
      }
      try {
        await _speech.listen(
          onResult: _onResult,
          listenOptions: SpeechListenOptions(
            localeId: localeId,
            onDevice: onDevice,
            partialResults: partialResults,
            listenMode: ListenMode.dictation,
            cancelOnError: true,
          ),
        );
      } on ListenFailedException catch (error) {
        // iOS reports an unsupported on-device recognizer as a failed listen (plugin code onDeviceError).
        final message = '${error.message} ${error.details}'.toLowerCase();
        _emit(
          onDevice && message.contains('on device')
              ? const SpeechOnDeviceUnavailable()
              : SpeechError(message.trim()),
          close: true,
        );
      } on PlatformException catch (error) {
        _emit(SpeechError(error.code), close: true);
      }
    }();
    return session.stream;
  }

  void _onResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      _gotFinal = true;
      _emit(SpeechFinal(result.recognizedWords), close: true);
    } else {
      _emit(SpeechPartial(result.recognizedWords));
    }
  }

  void _onError(SpeechRecognitionError error) {
    final code = error.errorMsg;
    final event = switch (code) {
      'error_no_match' || 'error_speech_timeout' => const SpeechNoSpeech(),
      // Android 12+: the on-device recognizer has no Korean pack.
      'error_language_unavailable' || 'error_language_not_supported'
          when _sessionOnDevice =>
        const SpeechOnDeviceUnavailable(),
      _ => SpeechError(code),
    };
    _emit(event, close: true);
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus && !_gotFinal) {
      _emit(const SpeechNoSpeech(), close: true);
    }
  }

  void _emit(SpeechEvent event, {bool close = false}) {
    final session = _session;
    if (session == null || session.isClosed) return;
    session.add(event);
    if (close) _closeSession();
  }

  void _closeSession() {
    final session = _session;
    _session = null;
    if (session != null && !session.isClosed) session.close();
  }

  @override
  Future<void> stop() async {
    if (_initialized != true) return;
    await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    _closeSession();
    if (_initialized != true) return;
    try {
      await _speech.cancel();
    } on PlatformException {
      // Already stopped.
    }
  }
}
