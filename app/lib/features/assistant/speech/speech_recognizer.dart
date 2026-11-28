import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_speech_recognizer.dart';

// SPEC-ASSIST-001 plan §A.0: the assistant knows only this port. It has no member that hands out audio:
// the device recognizer turns speech into text, and only that text ever reaches Kolbi (REQ-004).

/// The microphone and speech-recognition permissions, taken together: one refused means refused.
enum MicPermission {
  /// Not asked yet (or asked and refused once on Android): the purpose notice comes first (REQ-005).
  notDetermined,
  granted,

  /// Refused in the request that just ran.
  denied,

  /// Refused with "don't ask again" (or restricted): only the system settings can turn it on.
  permanentlyDenied,

  /// No recognizer or permission plugin on this platform (tests included): the assistant opens in text mode.
  unavailable,
}

/// What the recognizer reports during one listening session.
sealed class SpeechEvent {
  const SpeechEvent();
}

/// Words recognized so far; shown live, never sent.
final class SpeechPartial extends SpeechEvent {
  const SpeechPartial(this.text);
  final String text;
}

/// The final sentence of the session.
final class SpeechFinal extends SpeechEvent {
  const SpeechFinal(this.text);
  final String text;
}

/// The recognizer stopped without hearing speech.
final class SpeechNoSpeech extends SpeechEvent {
  const SpeechNoSpeech();
}

/// Any other recognizer error, with the platform's code.
final class SpeechError extends SpeechEvent {
  const SpeechError(this.code);
  final String code;
}

/// On-device recognition is not possible here (no language pack, unsupported device); REQ-006 retries once
/// with the platform's general recognizer after the OD-2 notice.
final class SpeechOnDeviceUnavailable extends SpeechEvent {
  const SpeechOnDeviceUnavailable();
}

abstract interface class SpeechRecognizer {
  Future<MicPermission> permission();

  /// Asks for the microphone and speech-recognition permissions in one flow.
  Future<MicPermission> requestPermission();

  Future<void> openAppSettings();

  /// The recognizer's own id for Korean (`ko-KR`, `ko_KR`), or null when it has none.
  Future<String?> koreanLocaleId();

  /// Starts one session; the stream ends after a final result, no speech or an error.
  Stream<SpeechEvent> listen({
    required String localeId,
    required bool onDevice,
    bool partialResults = true,
  });

  /// Ends listening; the recognizer then delivers the final sentence.
  Future<void> stop();

  /// Ends listening at once and drops the result (REQ-007). Safe to call more than once.
  Future<void> cancel();
}

/// The device recognizer; widget tests replace it with a fake (epic D-6).
final speechRecognizerProvider = Provider<SpeechRecognizer>(
  (ref) => PlatformSpeechRecognizer(),
);
