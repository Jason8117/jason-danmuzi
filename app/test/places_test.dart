// SPEC-PLACE-001 (place selection, place detail, location, plan card defaults). Only fakes: the places
// repository, the location reader and the speech recognizer are never real here.
import 'dart:async';

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

import 'package:flutter/services.dart';

import 'package:callmate/features/places/location/location_reader.dart';
import 'package:callmate/features/places/location/platform_location_reader.dart';

import 'support/fake_location_reader.dart';
import 'support/fake_places_repository.dart';
import 'support/fakes.dart' show taskJson;
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

const searchField = Key('place-search-field');
const searchAgain = Key('place-search-again');
const manual = Key('place-manual');
Key cardKey(String id) => Key('place-card-$id');
Key callKey(String id) => Key('place-call-$id');
Key detailKey(String id) => Key('place-detail-$id');

/// Opens place selection from the assistant with [text] and the intake [intake].
Future<PlacesApp> openPlaces(
  WidgetTester tester, {
  String text = pastaRequest,
  IntakeResult? intake,
  FakePlacesRepository? places,
  Size size = const Size(800, 2400),
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  final app = await pumpPlacesApp(
    tester,
    intake: intake ?? missingNumber(),
    places: places,
    size: size,
    textScale: textScale,
    overrides: overrides,
  );
  app.calls.nextCreated = CallTask.fromJson(taskJson(id: 'created-1'));
  await sendRequest(tester, text);
  expect(find.byType(PlaceSearchScreen), findsOneWidget);
  return app;
}

double top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

EditableText editable(WidgetTester tester, Key key) =>
    tester.widget<EditableText>(
      find.descendant(of: find.byKey(key), matching: find.byType(EditableText)),
    );

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

  // AC-010 (app) / REQ-010
  testWidgets('the search field starts from the request', (tester) async {
    var app = await openPlaces(tester);
    expect(editable(tester, searchField).controller.text, '강남역 파스타집');
    expect(app.places.queries, ['강남역 파스타집']);

    app = await openPlaces(tester, text: '해 줘');
    expect(editable(tester, searchField).controller.text, '');
    expect(editable(tester, searchField).focusNode.hasFocus, isTrue);
    expect(app.places.searchCalls, isEmpty);
    await tester.enterText(find.byKey(searchField), '망원동 세탁소');
    await tapAndSettle(tester, find.byKey(searchAgain));
    expect(app.places.queries, ['망원동 세탁소']);
    expect(app.places.searchCalls.single.near, isNull);
  });

  // AC-011 / REQ-011
  testWidgets('place selection follows the wireframe order', (tester) async {
    await openPlaces(tester);
    expect(find.text('장소 선택'), findsOneWidget);
    final order = [
      find.byKey(const Key('place-request-line')),
      find.text('고치기'),
      find.byKey(searchField),
      find.text('강남역 파스타집 4곳을 찾았어요'),
      find.byKey(cardKey('k1')),
      find.byKey(cardKey('k2')),
      find.byKey(cardKey('k3')),
      find.byKey(cardKey('k4')),
      find.text('장소 정보는 카카오 로컬 검색 결과예요'),
      find.byKey(manual),
    ];
    for (final finder in order) {
      expect(finder, findsOneWidget);
    }
    final tops = [for (final finder in order) top(tester, finder)];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThanOrEqualTo(tops[i - 1]), reason: 'item $i');
    }
    expect(top(tester, find.byKey(searchField)), greaterThan(tops[0]));
    expect(
      tester.widget<Text>(find.byKey(const Key('place-request-line'))).data,
      contains(pastaRequest),
    );

    final inFirst = find.descendant(
      of: find.byKey(cardKey('k1')),
      matching: find.text('가장 가까워요'),
    );
    expect(inFirst, findsOneWidget);
    expect(find.text('가장 가까워요'), findsOneWidget);
    expect(tester.widget(find.byKey(callKey('k1'))), isA<FilledButton>());
    expect(tester.widget(find.byKey(callKey('k2'))), isA<OutlinedButton>());
    for (final (id, name, distance, phone) in [
      ('k1', '라 파스타', '350m', '02-111-0000'),
      ('k2', '파스타 하우스', '600m', '02-222-0000'),
      ('k3', '봉골레 키친', '900m', null),
      ('k4', '응급 파스타', '1.2km', '119'),
    ]) {
      Finder inCard(Finder f) =>
          find.descendant(of: find.byKey(cardKey(id)), matching: f);
      expect(inCard(find.text(name)), findsOneWidget);
      expect(inCard(find.text('양식')), findsOneWidget);
      expect(inCard(find.text(distance)), findsOneWidget);
      if (phone != null) expect(inCard(find.text(phone)), findsOneWidget);
      expect(inCard(find.text('상세')), findsOneWidget);
      expect(inCard(find.text('여기로 전화')), findsOneWidget);
    }

    // [고치기] returns to the assistant with the sentence.
    await tapAndSettle(tester, find.text('고치기'));
    expect(find.byType(PlaceSearchScreen), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(field)).controller!.text,
      pastaRequest,
    );

    // Practice places and no distances.
    await openPlaces(
      tester,
      places: FakePlacesRepository(
        result: PlaceSearchResult(
          source: PlaceSearchSource.simulated,
          places: [
            for (final place in kakaoFour.places)
              Place(
                id: place.id,
                name: place.name,
                category: place.category,
                address: place.address,
                phone: place.phone,
                phoneNumber: place.phoneNumber,
                phoneCheck: place.phoneCheck,
              ),
          ],
        ),
      ),
    );
    expect(find.text('연습용 장소예요. 실제 가게가 아니에요'), findsOneWidget);
    expect(find.text('장소 정보는 카카오 로컬 검색 결과예요'), findsNothing);
    expect(find.text('가장 가까워요'), findsNothing);
  });

  // AC-012 / REQ-012
  testWidgets('loading, empty, failure and nothing callable', (tester) async {
    // (1) loading
    var places = FakePlacesRepository()..hold = Completer<void>();
    await openPlaces(tester, places: places);
    expect(find.text('강남역 파스타집을 찾는 중이에요'), findsOneWidget);
    expect(find.byKey(const Key('place-skeleton')), findsNWidgets(3));
    expect(find.byKey(manual), findsOneWidget);
    places.hold!.complete();
    await settle(tester);
    expect(find.byKey(const Key('place-skeleton')), findsNothing);
    expect(find.byKey(cardKey('k1')), findsOneWidget);

    // (2) nothing found
    await openPlaces(
      tester,
      places: FakePlacesRepository(
        result: const PlaceSearchResult(source: PlaceSearchSource.kakao),
      ),
    );
    expect(find.text('조건에 맞는 곳을 찾지 못했어요'), findsOneWidget);
    expect(find.byKey(manual), findsOneWidget);

    // (3) failed
    places = FakePlacesRepository()
      ..error = const ApiException(
        'place_search_failed',
        'Place search failed',
        statusCode: 502,
      );
    await openPlaces(tester, places: places);
    expect(find.text('장소를 찾지 못했어요. 잠시 뒤 다시 시도해 주세요'), findsOneWidget);
    expect(find.byKey(manual), findsOneWidget);
    await tapAndSettle(tester, find.text('다시 시도'));
    expect(places.searchCalls, hasLength(2));

    // (4) switched off
    places = FakePlacesRepository()
      ..error = const ApiException(
        'place_search_unavailable',
        'Place search is not available',
        statusCode: 503,
      );
    await openPlaces(tester, places: places);
    expect(find.text('지금은 장소 찾기를 쓸 수 없어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
    expect(find.byKey(manual), findsOneWidget);

    // (5) nothing callable: shown, never skipped to the plan card
    await openPlaces(
      tester,
      places: FakePlacesRepository(
        result: PlaceSearchResult(
          source: PlaceSearchSource.kakao,
          places: kakaoFour.places.sublist(2),
        ),
      ),
    );
    expect(find.byKey(cardKey('k3')), findsOneWidget);
    expect(find.byKey(cardKey('k4')), findsOneWidget);
    expect(find.text('전화할 수 있는 곳이 없어요'), findsOneWidget);
    expect(find.byType(PlanCardScreen), findsNothing);
    expect(find.byKey(manual), findsOneWidget);
  });

  // AC-013 / REQ-013
  testWidgets('uncallable candidates cannot be chosen', (tester) async {
    await openPlaces(tester);
    Finder inCard(String id, Finder f) =>
        find.descendant(of: find.byKey(cardKey(id)), matching: f);
    expect(inCard('k1', find.text('걸 수 있음')), findsOneWidget);
    expect(inCard('k3', find.text('번호 없음')), findsOneWidget);
    expect(inCard('k3', find.text('번호가 없어 전화할 수 없어요')), findsOneWidget);
    expect(inCard('k4', find.text('걸 수 없는 번호')), findsOneWidget);
    expect(inCard('k4', find.text('걸 수 없는 번호예요')), findsOneWidget);
    for (final id in ['k3', 'k4']) {
      expect(
        tester.widget<ButtonStyleButton>(find.byKey(callKey(id))).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(callKey(id)));
      await tester.tap(find.byKey(callKey(id)), warnIfMissed: false);
      await settle(tester);
      expect(find.byType(PlanCardScreen), findsNothing);
    }
    await tapAndSettle(tester, find.byKey(detailKey('k3')));
    expect(
      tester
          .widget<ButtonStyleButton>(find.byKey(const Key('place-ask')))
          .onPressed,
      isNull,
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('번호가 없어 전화할 수 없어요'),
      ),
      findsOneWidget,
    );
  });

  // AC-014 / REQ-014
  testWidgets('place detail sheet', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await openPlaces(tester);
    await tapAndSettle(tester, find.byKey(detailKey('k1')));
    final sheet = find.byType(BottomSheet);
    Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);
    expect(inSheet(find.text('라 파스타')), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'place-detail-title',
    );
    expect(inSheet(find.text('양식 · 350m')), findsOneWidget);
    expect(inSheet(find.text('서울 강남구 테헤란로 12')), findsOneWidget);
    expect(inSheet(find.text('02-111-0000')), findsOneWidget);
    expect(inSheet(find.text('여기에 물어보기')), findsOneWidget);
    await tapAndSettle(tester, inSheet(find.text('번호 복사')));
    expect(copied, ['02-111-0000']);
    await tapAndSettle(tester, inSheet(find.text('닫기')));
    expect(sheet, findsNothing);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'place-detail-button-k1',
    );

    await tapAndSettle(tester, find.byKey(detailKey('k3')));
    expect(inSheet(find.text('번호 복사')), findsNothing);
  });

  // AC-015 / REQ-015, AC-004 (app) / REQ-004
  testWidgets('choosing a place fills the plan card', (tester) async {
    final draft = missingNumber(conditions: const ['창가 자리']);
    Future<void> expectPlan(String name, String phone) async {
      expect(find.byType(PlanCardScreen), findsOneWidget);
      expect(find.text(name), findsOneWidget);
      expect(find.text(phone), findsOneWidget);
      expect(find.text('검색 결과'), findsOneWidget);
      expect(find.text('금요일 7시 2명 예약'), findsOneWidget);
      expect(find.text('창가 자리'), findsOneWidget);
      expect(find.byKey(const Key('plan-phone-field')), findsNothing);
    }

    // (1) [여기로 전화] on the first card
    var app = await openPlaces(tester, intake: draft);
    await tapAndSettle(tester, find.byKey(callKey('k1')));
    await expectPlan('라 파스타', '02-111-0000');
    expect(currentPath(tester), '/assistant/plan');
    await systemBack(tester);
    expect(find.byType(PlaceSearchScreen), findsOneWidget);
    expect(find.byKey(cardKey('k4')), findsOneWidget);
    expect(app.places.searchCalls, hasLength(1));
    await systemBack(tester);
    expect(find.byType(PlaceSearchScreen), findsNothing);
    expect(currentPath(tester), '/assistant');
    await tapAndSettle(tester, find.byKey(send));
    await tapAndSettle(tester, find.byKey(callKey('k1')));
    await tapAndSettle(tester, find.byKey(const Key('plan-start')));
    expect(app.calls.createRequests.single.targetName, '라 파스타');
    expect(app.calls.createRequests.single.phoneNumber, '+8221110000');

    // AC-004 (app): nothing about the places is stored on the device.
    final stored = [
      for (final key in app.preferences.getKeys())
        '$key=${app.preferences.get(key)}',
    ].join('\n');
    for (final marker in [
      '라 파스타',
      '파스타 하우스',
      '02-111-0000',
      '+8221110000',
      '테헤란로',
      'k1',
      'k2',
    ]) {
      expect(stored.contains(marker), isFalse, reason: marker);
    }

    // (2) [상세] → [여기에 물어보기]
    await openPlaces(tester, intake: draft);
    await tapAndSettle(tester, find.byKey(detailKey('k2')));
    await tapAndSettle(tester, find.byKey(const Key('place-ask')));
    await expectPlan('파스타 하우스', '02-222-0000');

    // (3) [번호 직접 입력]
    await openPlaces(tester, intake: draft);
    await tapAndSettle(tester, find.byKey(manual));
    expect(find.byType(PlanCardScreen), findsOneWidget);
    final phoneField = find.byKey(const Key('plan-phone-field'));
    expect(phoneField, findsOneWidget);
    expect(top(tester, phoneField), lessThan(top(tester, find.text('전화할 곳'))));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('plan-target-field')))
          .controller!
          .text,
      '',
    );

    // (4) a representative number
    app = await openPlaces(
      tester,
      intake: draft,
      places: FakePlacesRepository(
        result: const PlaceSearchResult(
          source: PlaceSearchSource.kakao,
          places: [
            Place(
              id: 'rep',
              name: '고객센터 대표',
              phone: '1588-0000',
              phoneNumber: '+15880000',
              phoneCheck: PlacePhoneCheck.ok,
            ),
          ],
        ),
      ),
    );
    await tapAndSettle(tester, find.byKey(callKey('rep')));
    expect(find.text('1588-0000'), findsOneWidget);
    expect(find.textContaining('+15880000'), findsNothing);
    await tapAndSettle(tester, find.byKey(const Key('plan-start')));
    expect(app.calls.createRequests.single.phoneNumber, '+15880000');
  });

  // acceptance.md edge case: closing place selection while it searches.
  testWidgets('a late answer after leaving place selection is ignored', (
    tester,
  ) async {
    final places = FakePlacesRepository()..hold = Completer<void>();
    await openPlaces(tester, places: places);
    await systemBack(tester);
    expect(find.byType(PlaceSearchScreen), findsNothing);
    places.hold!.complete();
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(currentPath(tester), '/assistant');
  });

  // AC-016 / REQ-016
  testWidgets('nearby asks for location with a purpose first', (tester) async {
    const nearby = '근처 약국 오늘 몇 시까지 하는지 물어봐 줘';
    const purpose =
        '근처 가게를 찾으려면 지금 위치가 필요해요. 가까운 가게를 찾는 데만 써요. 콜비는 위치를 저장하지 않아요.';
    Future<(PlacesApp, FakeLocationReader)> open(
      FakeLocationReader location,
    ) async {
      final app = await openPlaces(
        tester,
        text: nearby,
        overrides: [locationReaderProvider.overrideWithValue(location)],
      );
      return (app, location);
    }

    // (1) not asked yet → purpose → [계속] → OS dialog → allowed
    var (app, location) = await open(FakeLocationReader());
    expect(find.text(purpose), findsOneWidget);
    expect(find.textContaining('위치는 검색에만'), findsNothing);
    expect(location.requestCalls, 0);
    expect(app.places.searchCalls, isEmpty);
    await tapAndSettle(
      tester,
      find.byKey(const Key('location-consent-continue')),
    );
    expect(location.requestCalls, 1);
    expect(app.places.searchCalls.last.query, '약국');
    expect(app.places.searchCalls.last.near, (lat: 37.55, lng: 126.91));
    expect(find.byKey(cardKey('k1')), findsOneWidget);

    // (2) not asked yet → denied → neighbourhood field
    (app, location) = await open(
      FakeLocationReader(answer: LocationAccess.denied),
    );
    await tapAndSettle(
      tester,
      find.byKey(const Key('location-consent-continue')),
    );
    expect(find.text('동네 이름을 알려 주세요'), findsOneWidget);
    expect(find.byKey(const Key('location-open-settings')), findsNothing);
    expect(app.places.searchCalls, isEmpty);
    await tester.enterText(find.byKey(const Key('place-area-field')), '망원동');
    await tapAndSettle(tester, find.byKey(const Key('place-area-search')));
    expect(app.places.searchCalls.single.query, '망원동 약국');
    expect(app.places.searchCalls.single.near, isNull);

    // (3) never ask again → field and [설정 열기], no purpose notice
    (app, location) = await open(
      FakeLocationReader(state: LocationAccess.deniedForever),
    );
    expect(find.text(purpose), findsNothing);
    expect(find.text('동네 이름을 알려 주세요'), findsOneWidget);
    expect(find.text('설정에서 위치 권한을 켜면 근처를 찾을 수 있어요'), findsOneWidget);
    await tapAndSettle(tester, find.byKey(const Key('location-open-settings')));
    expect(location.settingsCalls, 1);
    expect(location.requestCalls, 0);

    // (4) allowed but reading fails, (5) allowed but no answer for 11 s, (6) no location at all
    for (final reader in [
      FakeLocationReader(state: LocationAccess.granted, position: null),
      FakeLocationReader(
        state: LocationAccess.granted,
        delay: const Duration(seconds: 11),
      ),
      FakeLocationReader(state: LocationAccess.unavailable),
    ]) {
      (app, location) = await open(reader);
      if (reader.delay != null) {
        await tester.pump(const Duration(seconds: 11));
        await settle(tester);
      }
      expect(find.text(purpose), findsNothing);
      expect(find.text('동네 이름을 알려 주세요'), findsOneWidget);
      expect(app.places.searchCalls, isEmpty);
      expect(tester.takeException(), isNull);
    }
  });

  // AC-017 / REQ-017
  testWidgets('location stays out of storage and other requests', (
    tester,
  ) async {
    // (1) after a nearby search with a position
    var location = FakeLocationReader();
    var app = await openPlaces(
      tester,
      text: '근처 약국 오늘 몇 시까지 하는지 물어봐 줘',
      overrides: [locationReaderProvider.overrideWithValue(location)],
    );
    await tapAndSettle(
      tester,
      find.byKey(const Key('location-consent-continue')),
    );
    expect(app.places.searchCalls.last.near, isNotNull);
    final stored = [
      for (final key in app.preferences.getKeys())
        '$key=${app.preferences.get(key)}',
    ].join('\n');
    expect(stored.contains('37.55'), isFalse);
    expect(stored.contains('126.91'), isFalse);

    // (2) a request that is not "nearby" never touches the location
    location = FakeLocationReader(state: LocationAccess.granted);
    app = await openPlaces(
      tester,
      overrides: [locationReaderProvider.overrideWithValue(location)],
    );
    expect(
      location.accessCalls + location.requestCalls + location.readCalls,
      0,
    );
    expect(app.places.searchCalls.single.near, isNull);
  });

  testWidgets(
    'without a location plugin a nearby request asks for the neighbourhood',
    (tester) async {
      // The real reader: flutter_test has no geolocator plugin, which must read as "unavailable".
      final app = await openPlaces(tester, text: '근처 약국 오늘 몇 시까지 하는지 물어봐 줘');
      expect(find.text('동네 이름을 알려 주세요'), findsOneWidget);
      expect(app.places.searchCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  test('a forced platform reader without a plugin reports unavailable, never throws', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final forced = PlatformLocationReader(supported: true);
    expect(await forced.access(), LocationAccess.unavailable);
    expect(await forced.request(), LocationAccess.unavailable);
    expect(await forced.readOnce(), isNull);
    await forced.openSettings();
    final host = PlatformLocationReader();
    expect(await host.access(), LocationAccess.unavailable);
    expect(await host.readOnce(), isNull);
  });
}
