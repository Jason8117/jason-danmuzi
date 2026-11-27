// SPEC-ASSIST-001: the only recognizer widget tests use (epic D-6). Each listen plays the next script.
import 'dart:async';

import 'package:callmate/features/assistant/speech/speech_recognizer.dart';

typedef ListenCall = ({String localeId, bool onDevice, bool partialResults});

class FakeSpeechRecognizer implements SpeechRecognizer {
  FakeSpeechRecognizer({
    this.status = MicPermission.granted,
    this.requestResult = MicPermission.granted,
    List<List<SpeechEvent>>? sessions,
    this.localeId = 'ko-KR',
    this.gap = const Duration(milliseconds: 100),
  }) : sessions = sessions ?? [];

  MicPermission status;
  MicPermission requestResult;

  /// One script per `listen` call, in order; a call past the end plays nothing and keeps listening.
  final List<List<SpeechEvent>> sessions;
  String? localeId;

  /// Time between scripted events (the first one included).
  final Duration gap;

  final listenCalls = <ListenCall>[];
  int requestCalls = 0;
  int settingsCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  StreamController<SpeechEvent>? _session;
  String _lastPartial = '';
  bool get isListening => _session != null;

  /// Sends [event] into the session that is (or was last) open, as a late recognizer would.
  final _late = <StreamController<SpeechEvent>>[];
  void emitLate(SpeechEvent event) {
    for (final c in _late) {
      if (!c.isClosed) c.add(event);
    }
  }

  @override
  Future<MicPermission> permission() async => status;

  @override
  Future<MicPermission> requestPermission() async {
    requestCalls++;
    status = requestResult;
    return requestResult;
  }

  @override
  Future<void> openAppSettings() async => settingsCalls++;

  @override
  Future<String?> koreanLocaleId() async => localeId;

  @override
  Stream<SpeechEvent> listen({
    required String localeId,
    required bool onDevice,
    bool partialResults = true,
  }) {
    listenCalls.add((
      localeId: localeId,
      onDevice: onDevice,
      partialResults: partialResults,
    ));
    final script = listenCalls.length <= sessions.length
        ? sessions[listenCalls.length - 1]
        : const <SpeechEvent>[];
    final controller = _session = StreamController<SpeechEvent>();
    _late.add(controller);
    _lastPartial = '';
    () async {
      for (final event in script) {
        await Future<void>.delayed(gap);
        if (controller.isClosed) return;
        if (event is SpeechPartial) _lastPartial = event.text;
        controller.add(event);
        if (event is! SpeechPartial) {
          _end(controller);
          return;
        }
      }
    }();
    return controller.stream;
  }

  void _end(StreamController<SpeechEvent> controller) {
    if (identical(_session, controller)) _session = null;
  }

  /// Like the plugin: stopping delivers the last words as the final result.
  @override
  Future<void> stop() async {
    stopCalls++;
    final controller = _session;
    if (controller == null) return;
    _end(controller);
    controller.add(SpeechFinal(_lastPartial));
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    final controller = _session;
    if (controller != null) _end(controller);
  }
}
