// SPEC-ASSIST-001 AC-001 .. AC-010, AC-014 (assistant). The recognizer is always the fake, except where a
// test checks that the real one degrades without plugins.
import 'package:callmate/features/assistant/speech/platform_speech_recognizer.dart';
import 'package:callmate/features/assistant/speech/speech_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('speech port (M1)', () {
    test('without plugins the platform recognizer reports unavailable, never throws', () async {
      final recognizer = PlatformSpeechRecognizer();
      expect(await recognizer.permission(), MicPermission.unavailable);
      expect(await recognizer.requestPermission(), MicPermission.unavailable);
      expect(await recognizer.koreanLocaleId(), isNull);
      final events = await recognizer
          .listen(localeId: 'ko-KR', onDevice: true)
          .toList();
      expect(events.single, isA<SpeechError>());
      await recognizer.stop();
      await recognizer.cancel();
      await recognizer.cancel();
      await recognizer.openAppSettings();
    });
  });
}
