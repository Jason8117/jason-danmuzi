// SPEC-ASSIST-001 sync audit 1 (S2, M2): the speech adapter over a scripted SpeechToText. No platform
// channel reaches a device; the permission plugin's channel is answered by a mock handler.
import 'dart:async';

import 'package:callmate/features/assistant/speech/platform_speech_recognizer.dart';
import 'package:callmate/features/assistant/speech/speech_recognizer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// What one `listen` call does: throw, or report through the callbacks given to `initialize`/`listen`.
typedef ListenScript = FutureOr<void> Function(ScriptedSpeech speech);

class ScriptedSpeech extends SpeechToText {
  ScriptedSpeech({
    this.initializes = true,
    this.localeIds = const ['en_US', 'ko_KR'],
    this.onListen,
  }) : super.withMethodChannel();

  final bool initializes;
  final List<String> localeIds;
  ListenScript? onListen;

  SpeechErrorListener? onErrorGiven;
  SpeechStatusListener? onStatusGiven;
  SpeechResultListener? resultListener;
  SpeechListenOptions? lastOptions;
  int initializeCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    initializeCalls++;
    onErrorGiven = onError;
    onStatusGiven = onStatus;
    return initializes;
  }

  @override
  Future<List<LocaleName>> locales() async => [
    for (final id in localeIds) LocaleName(id, id),
  ];

  @override
  Future listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    listenCalls++;
    resultListener = onResult;
    lastOptions = listenOptions;
    await onListen?.call(this);
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> cancel() async => cancelCalls++;

  void result(String words, {required bool last}) => resultListener!(
    SpeechRecognitionResult.init([
      SpeechRecognitionWords(words, null, 0.9),
    ], last ? ResultType.finalResult : ResultType.partial),
  );

  void error(String code) => onErrorGiven!(SpeechRecognitionError(code, true));
}

Future<List<SpeechEvent>> session(
  PlatformSpeechRecognizer recognizer, {
  bool onDevice = true,
}) => recognizer
    .listen(localeId: 'ko-KR', onDevice: onDevice)
    .toList()
    .timeout(const Duration(seconds: 1));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PlatformSpeechRecognizer adapter(ScriptedSpeech speech) =>
      PlatformSpeechRecognizer(speech: speech, supported: true);

  group('listening', () {
    test('partial words, then the final sentence', () async {
      final speech = ScriptedSpeech(
        onListen: (s) {
          s.result('금요일', last: false);
          s.result('금요일 7시', last: true);
        },
      );
      final events = await session(adapter(speech));
      expect(events, hasLength(2));
      expect((events[0] as SpeechPartial).text, '금요일');
      expect((events[1] as SpeechFinal).text, '금요일 7시');
      expect(speech.lastOptions!.localeId, 'ko-KR');
      expect(speech.lastOptions!.onDevice, isTrue);
      expect(speech.lastOptions!.partialResults, isTrue);
      expect(speech.lastOptions!.cancelOnError, isTrue);
      expect(speech.lastOptions!.listenMode, ListenMode.dictation);
    });

    test('done without a final result means no speech', () async {
      final speech = ScriptedSpeech(
        onListen: (s) => s.onStatusGiven!(SpeechToText.doneStatus),
      );
      final events = await session(adapter(speech));
      expect(events.single, isA<SpeechNoSpeech>());
    });

    test('a recognizer that does not initialize reports unavailable', () async {
      final speech = ScriptedSpeech(initializes: false);
      final recognizer = adapter(speech);
      final events = await session(recognizer);
      expect((events.single as SpeechError).code, 'unavailable');
      expect(await recognizer.koreanLocaleId(), isNull);
      expect(speech.initializeCalls, 1, reason: 'the result is remembered');
      await recognizer.stop();
      await recognizer.cancel();
      expect(speech.stopCalls, 0);
      expect(speech.cancelCalls, 0);
    });

    test('stop and cancel reach the recognizer once initialized', () async {
      final speech = ScriptedSpeech();
      final recognizer = adapter(speech);
      expect(await recognizer.koreanLocaleId(), 'ko_KR');
      await recognizer.stop();
      await recognizer.cancel();
      expect(speech.stopCalls, 1);
      expect(speech.cancelCalls, 1);
    });

    test('the Korean locale is found by its language, or not at all', () async {
      for (final (ids, expected) in <(List<String>, String?)>[
        (['en_US', 'ko-KR'], 'ko-KR'),
        (['KO'], 'KO'),
        (['en_US', 'kok_IN'], null),
        ([], null),
      ]) {
        final recognizer = adapter(ScriptedSpeech(localeIds: ids));
        expect(await recognizer.koreanLocaleId(), expected, reason: '$ids');
      }
    });
  });

  group('errors', () {
    test('recognizer error codes become the port events', () async {
      for (final (code, onDevice, matcher) in <(String, bool, Matcher)>[
        ('error_no_match', true, isA<SpeechNoSpeech>()),
        ('error_speech_timeout', false, isA<SpeechNoSpeech>()),
        ('error_language_unavailable', true, isA<SpeechOnDeviceUnavailable>()),
        (
          'error_language_not_supported',
          true,
          isA<SpeechOnDeviceUnavailable>(),
        ),
        // The general recognizer has no on-device fallback to offer.
        ('error_language_unavailable', false, isA<SpeechError>()),
        ('error_network', true, isA<SpeechError>()),
      ]) {
        final speech = ScriptedSpeech(onListen: (s) => s.error(code));
        final events = await session(adapter(speech), onDevice: onDevice);
        expect(events.single, matcher, reason: '$code onDevice=$onDevice');
        if (events.single case SpeechError(code: final c)) {
          expect(c, code);
        }
      }
    });

    // M2: the iOS plugin reports onDeviceError and then still starts the audio engine (no return in
    // SpeechToTextPlugin.swift listenForSpeech), so the adapter must turn the microphone off itself.
    test('iOS without on-device recognition: the OD-2 event and the microphone off', () async {
      final speech = ScriptedSpeech(
        onListen: (s) => throw ListenFailedException(
          'on device recognition is not supported on this device',
        ),
      );
      final events = await session(adapter(speech));
      expect(events.single, isA<SpeechOnDeviceUnavailable>());
      expect(speech.cancelCalls, 1);
    });

    test(
      'Android without the on-device language pack: the microphone off too',
      () async {
        final speech = ScriptedSpeech(
          onListen: (s) => s.error('error_language_unavailable'),
        );
        final events = await session(adapter(speech));
        expect(events.single, isA<SpeechOnDeviceUnavailable>());
        expect(speech.cancelCalls, greaterThan(0));
      },
    );

    test('other failed listens are errors, not the OD-2 notice', () async {
      // The same message without on-device listening is an ordinary error.
      var speech = ScriptedSpeech(
        onListen: (s) => throw ListenFailedException(
          'on device recognition is not supported on this device',
        ),
      );
      var events = await session(adapter(speech), onDevice: false);
      expect(events.single, isA<SpeechError>());

      speech = ScriptedSpeech(
        onListen: (s) =>
            throw ListenFailedException('Failed to create speech recognizer'),
      );
      events = await session(adapter(speech));
      expect(
        (events.single as SpeechError).code,
        'failed to create speech recognizer',
      );
      expect(speech.cancelCalls, greaterThan(0));

      speech = ScriptedSpeech(
        onListen: (s) => throw PlatformException(code: 'busy'),
      );
      events = await session(adapter(speech));
      expect((events.single as SpeechError).code, 'busy');
    });

    test('events after the session ended are dropped', () async {
      final speech = ScriptedSpeech(
        onListen: (s) {
          s.result('다 했어요', last: true);
          s.error('error_network');
          s.onStatusGiven!(SpeechToText.doneStatus);
        },
      );
      final events = await session(adapter(speech));
      expect(events.single, isA<SpeechFinal>());
    });
  });

  group('permissions', () {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    // permission_handler's wire values.
    const denied = 0, granted = 1, restricted = 2, limited = 3, permanent = 4;
    const microphone = 7, speechPermission = 14;

    void answer({required Map<int, int> check, Map<int, int>? request}) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'checkPermissionStatus':
                return check[call.arguments as int];
              case 'requestPermissions':
                return request;
              case 'openAppSettings':
                return true;
            }
            return null;
          });
    }

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('two permissions are combined into one state', () async {
      final recognizer = adapter(ScriptedSpeech());
      for (final (mic, speech, expected) in <(int, int, MicPermission)>[
        (granted, granted, MicPermission.granted),
        (granted, limited, MicPermission.granted),
        (granted, denied, MicPermission.notDetermined),
        (permanent, granted, MicPermission.permanentlyDenied),
        (granted, restricted, MicPermission.permanentlyDenied),
      ]) {
        answer(check: {microphone: mic, speechPermission: speech});
        expect(await recognizer.permission(), expected, reason: '$mic $speech');
      }
    });

    test('after a request a refusal is denied, not "not asked"', () async {
      final recognizer = adapter(ScriptedSpeech());
      answer(
        check: {},
        request: {microphone: granted, speechPermission: denied},
      );
      expect(await recognizer.requestPermission(), MicPermission.denied);
      answer(
        check: {},
        request: {microphone: granted, speechPermission: granted},
      );
      expect(await recognizer.requestPermission(), MicPermission.granted);
      answer(
        check: {},
        request: {microphone: permanent, speechPermission: granted},
      );
      expect(
        await recognizer.requestPermission(),
        MicPermission.permanentlyDenied,
      );
      await recognizer.openAppSettings();
    });
  });
}
