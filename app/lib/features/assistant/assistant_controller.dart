import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'speech/speech_recognizer.dart';

// SPEC-ASSIST-001 plan §A.1: the assistant's one state, driven only by the speech port.

enum AssistantPhase {
  /// Asking the port for the permission state.
  starting,

  /// Waiting; the orb starts listening when tapped.
  idle,

  /// The purpose notice before the OS dialog (REQ-005, CMP-23).
  consent,

  /// Refused with "don't ask again": a settings line instead of the notice (REQ-005).
  settingsNeeded,

  /// On-device recognition is not available: the OD-2 notice before the general recognizer (REQ-006).
  fallbackConsent,

  /// Android, first dictation: who may turn speech into text, shown once before listening (OD-2 deviation,
  /// owner decision 2026-11-28 — the plugin falls back to the network recognizer without telling the app).
  speechServiceNotice,
  listening,

  /// The final sentence is on its way to intake.
  processing,

  /// The request box (REQ-008).
  text,
}

@immutable
class AssistantState {
  const AssistantState(this.phase, {this.words = '', this.notice});

  final AssistantPhase phase;

  /// The words heard so far while listening, the sentence while processing, or the text to put in the input
  /// on entering text mode.
  final String words;

  /// A one-line message under the orb (failures, refused microphone).
  final String? notice;

  bool get isText => phase == AssistantPhase.text;

  /// The status chip; the orb follows the same three states (REQ-002).
  String get statusLabel => switch (phase) {
    AssistantPhase.listening => '듣고 있어요',
    AssistantPhase.processing => '처리하고 있어요',
    _ => '기다리고 있어요',
  };
}

/// What the assistant remembers while the app runs (REQ-006, plan §A.1); never stored.
class AssistantMemory {
  /// Consecutive recognition failures; a success resets it.
  int failures = 0;

  /// Two failures in a row: later opens wait for a tap instead of listening at once.
  bool autoListenOff = false;

  /// The user accepted the general recognizer once (OD-2), so on-device is not tried again.
  bool generalRecognizer = false;
}

final assistantMemoryProvider = Provider<AssistantMemory>(
  (ref) => AssistantMemory(),
);

const heardNothing = '잘 못 들었어요. 다시 말하거나 글로 적어 주세요';
const noMicrophone = '마이크 없이도 글로 부탁할 수 있어요';
const noKorean = '이 기기에서는 말로 부탁하기를 쓸 수 없어요';

// @MX:ANCHOR: [AUTO] The only owner of a listening session; the screen, its lifecycle hook and dispose all
// end dictation here.
// @MX:REASON: REQ-007 — after the screen closes the microphone must be off, and late recognizer events must
// never reach intake; every exit path goes through cancel()/dispose().
// @MX:SPEC: SPEC-ASSIST-001 REQ-003, REQ-006, REQ-007
class AssistantController extends ValueNotifier<AssistantState> {
  AssistantController({
    required this.recognizer,
    required this.memory,
    required this.onFinal,
    bool Function()? needsSpeechServiceNotice,
    void Function()? acknowledgeSpeechServiceNotice,
  }) : _needsSpeechServiceNotice = needsSpeechServiceNotice ?? _never,
       _acknowledgeSpeechServiceNotice = acknowledgeSpeechServiceNotice ?? _noop,
       super(const AssistantState(AssistantPhase.starting));

  static bool _never() => false;
  static void _noop() {}

  final bool Function() _needsSpeechServiceNotice;
  final void Function() _acknowledgeSpeechServiceNotice;

  final SpeechRecognizer recognizer;
  final AssistantMemory memory;

  /// Called once with a non-empty final sentence; the screen sends it to intake.
  final void Function(String sentence) onFinal;

  StreamSubscription<SpeechEvent>? _session;
  String? _localeId;
  bool _onDevice = true;
  bool _closed = false;

  void _set(AssistantState next) {
    if (!_closed) value = next;
  }

  /// Opening the screen: text mode when asked for, else the permission flow and (OD-3) listening at once.
  Future<void> start({required bool textMode}) async {
    if (textMode) return _set(const AssistantState(AssistantPhase.text));
    await _begin(auto: true);
  }

  /// The orb: listen again from waiting.
  Future<void> tapOrb() async {
    if (value.phase != AssistantPhase.idle) return;
    await _begin(auto: false);
  }

  Future<void> _begin({required bool auto}) async {
    final permission = await recognizer.permission();
    if (_closed) return;
    switch (permission) {
      case MicPermission.unavailable:
        _toText();
      case MicPermission.granted:
        if (auto && memory.autoListenOff) {
          _set(const AssistantState(AssistantPhase.idle));
        } else {
          await _listen();
        }
      case MicPermission.notDetermined:
        _set(const AssistantState(AssistantPhase.consent));
      case MicPermission.denied:
        _toText(notice: noMicrophone);
      case MicPermission.permanentlyDenied:
        _set(const AssistantState(AssistantPhase.settingsNeeded));
    }
  }

  /// [계속] on the purpose notice: only now does the OS dialog appear.
  Future<void> acceptConsent() async {
    if (value.phase != AssistantPhase.consent) return;
    // On Android the purpose notice also carries the speech-service sentence, so [계속] acknowledges it.
    if (_needsSpeechServiceNotice()) _acknowledgeSpeechServiceNotice();
    final permission = await recognizer.requestPermission();
    if (_closed) return;
    switch (permission) {
      case MicPermission.granted:
        await _listen();
      case MicPermission.permanentlyDenied:
        _set(const AssistantState(AssistantPhase.settingsNeeded));
      case MicPermission.unavailable:
        _toText();
      case MicPermission.notDetermined || MicPermission.denied:
        _toText(notice: noMicrophone);
    }
  }

  Future<void> openSettings() => recognizer.openAppSettings();

  /// [계속] on the Android speech-service notice: remember it, then listen.
  Future<void> acceptSpeechServiceNotice() async {
    if (value.phase != AssistantPhase.speechServiceNotice) return;
    _acknowledgeSpeechServiceNotice();
    await _listen();
  }

  Future<void> _listen() async {
    if (_needsSpeechServiceNotice()) {
      return _set(const AssistantState(AssistantPhase.speechServiceNotice));
    }
    final locale = _localeId ??= await recognizer.koreanLocaleId();
    if (_closed) return;
    if (locale == null) return _toText(notice: noKorean);
    _start(locale, onDevice: !memory.generalRecognizer);
  }

  void _start(String locale, {required bool onDevice}) {
    _session?.cancel();
    _onDevice = onDevice;
    _set(const AssistantState(AssistantPhase.listening));
    _session = recognizer
        .listen(localeId: locale, onDevice: onDevice)
        .listen(_onEvent);
  }

  void _onEvent(SpeechEvent event) {
    if (_closed || value.phase != AssistantPhase.listening) return;
    switch (event) {
      case SpeechPartial(:final text):
        _set(AssistantState(AssistantPhase.listening, words: text));
      case SpeechFinal(:final text):
        _endSession();
        final sentence = text.trim();
        if (sentence.isEmpty) return _fail();
        memory.failures = 0;
        _set(AssistantState(AssistantPhase.processing, words: sentence));
        onFinal(sentence);
      case SpeechOnDeviceUnavailable() when _onDevice:
        _endSession();
        memory.failures++;
        _set(const AssistantState(AssistantPhase.fallbackConsent));
      case SpeechNoSpeech() || SpeechError() || SpeechOnDeviceUnavailable():
        _endSession();
        _fail();
    }
  }

  /// REQ-006: a failure goes back to waiting; the second in a row goes to text mode and stops listening on
  /// open for the rest of this run of the app.
  void _fail() {
    memory.failures++;
    if (memory.failures >= 2) {
      memory.autoListenOff = true;
      _toText(notice: heardNothing);
    } else {
      _set(const AssistantState(AssistantPhase.idle, notice: heardNothing));
    }
  }

  /// [계속] on the OD-2 notice: the general recognizer, once, in the same request.
  void acceptGeneralRecognizer() {
    if (value.phase != AssistantPhase.fallbackConsent || _localeId == null) {
      return;
    }
    memory.generalRecognizer = true;
    _start(_localeId!, onDevice: false);
  }

  /// [말하기 끝]: the recognizer delivers the final sentence.
  Future<void> finishSpeaking() async {
    if (value.phase == AssistantPhase.listening) await recognizer.stop();
  }

  /// [글로 입력]: stop listening and keep the words heard so far.
  void switchToText() {
    final words = value.phase == AssistantPhase.listening ? value.words : '';
    _stopListening();
    _toText(words: words);
  }

  /// [그만하기], leaving, the app going to the background: drop the words (REQ-007).
  void cancel() {
    final wasListening = value.phase == AssistantPhase.listening;
    _stopListening();
    if (wasListening) _set(const AssistantState(AssistantPhase.idle));
  }

  /// After a spoken request was handled (or failed to send): the sentence stays, as text, for editing.
  void keepAsText(String sentence) => _toText(words: sentence);

  void _toText({String words = '', String? notice}) =>
      _set(AssistantState(AssistantPhase.text, words: words, notice: notice));

  void _endSession() {
    _session?.cancel();
    _session = null;
  }

  void _stopListening() {
    _endSession();
    recognizer.cancel();
  }

  @override
  void dispose() {
    _closed = true;
    _stopListening();
    super.dispose();
  }
}
