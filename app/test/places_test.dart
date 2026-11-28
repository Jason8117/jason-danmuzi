// SPEC-PLACE-001 (place selection, place detail, location, plan card defaults). Only fakes: the places
// repository, the location reader and the speech recognizer are never real here.
import 'package:callmate/app.dart';
import 'package:callmate/core/clock.dart';
import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/features/assistant/speech/speech_recognizer.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/presentation/plan_card_screen.dart';
import 'package:callmate/features/places/place_search_screen.dart';
import 'package:callmate/shell/navigation.dart';
import 'package:callmate/shell/place_search.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_places_repository.dart';
import 'support/fake_speech_recognizer.dart';
import 'support/shell_support.dart';

const field = Key('home-intake-field');
const send = Key('home-intake-send');
const profile = {
  'requesterName': '김민수',
  'trustNoticeAcknowledged': true,
  'androidSpeechServiceNoticeAcknowledged': true,
};

const pastaRequest = '강남역 근처 파스타집, 금요일 7시 2명 예약해 줘';

IntakeResult missingNumber({
  String goal = '금요일 7시 2명 예약',
  String? targetName,
  List<String> conditions = const [],
  bool blocked = false,
}) => IntakeResult(
  draft: PlanDraft(
    goal: goal,
    targetName: targetName,
    conditions: conditions,
    numberBlocked: blocked,
  ),
  missing: const ['phoneNumber'],
);

class PlacesApp {
  PlacesApp(this.calls, this.places, this.preferences);
  final CountingCallsRepository calls;
  final FakePlacesRepository places;
  final SharedPreferences preferences;
}

/// The whole app with fake calls and places repositories, opened on the assistant in text mode.
Future<PlacesApp> pumpPlacesApp(
  WidgetTester tester, {
  IntakeResult? intake,
  Object? intakeError,
  FakePlacesRepository? places,
  Size size = const Size(800, 2400),
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(const SizedBox());
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  SharedPreferences.setMockInitialValues(profile);
  final preferences = await SharedPreferences.getInstance();
  final calls = CountingCallsRepository(const [])
    ..intakeResult = intake
    ..intakeError = intakeError;
  final placesRepo = places ?? FakePlacesRepository();
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        callsRepositoryProvider.overrideWithValue(calls),
        placesRepositoryProvider.overrideWithValue(placesRepo),
        clockProvider.overrideWithValue(() => shellNow),
        speechRecognizerProvider.overrideWithValue(FakeSpeechRecognizer()),
        ...overrides,
      ],
      child: const CallMateApp(),
    ),
  );
  await settle(tester);
  openAssistant(appRouter(tester), text: true);
  await settle(tester);
  return PlacesApp(calls, placesRepo, preferences);
}

/// Types [text] into the assistant and sends it.
Future<void> sendRequest(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(field), text);
  await tester.pump();
  await tapAndSettle(tester, find.byKey(send));
}

String currentPath(WidgetTester tester) => appRouter(tester).state.uri.path;

Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester);
}

void main() {
  // AC-009 / REQ-009
  testWidgets(
    'the assistant opens place selection only when the number is missing',
    (tester) async {
      for (final intake in [
        missingNumber(),
        missingNumber(targetName: '라 파스타'),
      ]) {
        final app = await pumpPlacesApp(tester, intake: intake);
        await sendRequest(tester, pastaRequest);
        expect(find.byType(PlaceSearchScreen), findsOneWidget);
        expect(find.byType(PlanCardScreen), findsNothing);
        expect(currentPath(tester), '/assistant/places');
        expect(find.byKey(tabToday).hitTestable(), findsNothing);
        expect(app.calls.intakeCalls, [pastaRequest]);

        await systemBack(tester);
        expect(find.byType(PlaceSearchScreen), findsNothing);
        expect(currentPath(tester), '/assistant');
        expect(
          tester.widget<TextField>(find.byKey(field)).controller!.text,
          pastaRequest,
        );
      }

      final others = <({IntakeResult? intake, Object? error})>[
        (
          intake: const IntakeResult(
            draft: PlanDraft(
              goal: '예약',
              targetName: '라 파스타',
              phoneNumber: '+8221110000',
            ),
          ),
          error: null,
        ),
        (intake: missingNumber(blocked: true), error: null),
        (
          intake: null,
          error: const ApiException('not_found', 'Not Found', statusCode: 404),
        ),
        (intake: null, error: null),
      ];
      for (final other in others) {
        final app = await pumpPlacesApp(
          tester,
          intake: other.intake,
          intakeError: other.error,
        );
        await sendRequest(tester, pastaRequest);
        expect(find.byType(PlaceSearchScreen), findsNothing);
        expect(find.byType(PlanCardScreen), findsOneWidget);
        expect(currentPath(tester), '/assistant/plan');
        expect(app.places.searchCalls, isEmpty);
      }
    },
  );
}
