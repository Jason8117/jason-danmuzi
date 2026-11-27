import 'dart:io';

import 'package:callmate/app.dart';
import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

// SPEC-DESIGN-001 AC-005: the real Pretendard glyphs (not the Ahem test font) fit the home screen.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko');
    // The family name must match the theme's `packages/kolbi_ui/Pretendard`, or text falls back to Ahem.
    final bytes = File(
      '../packages/kolbi_ui/assets/fonts/PretendardVariable.ttf',
    ).readAsBytesSync();
    await (FontLoader(
      'packages/kolbi_ui/Pretendard',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  testWidgets('home fits a 360x640 phone at 2x text with the real font', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    SharedPreferences.setMockInitialValues({
      'requesterName': '김민수',
      'trustNoticeAcknowledged': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final tasks = [
      CallTask.fromJson(taskJson(id: 'live-1')),
      CallTask.fromJson({
        ...taskJson(
          id: 'done-1',
          status: 'completed',
          outcome: {
            'result': 'success',
            'source': 'llm',
            'summary': '미용실 통화를 마쳤어요.',
            'keyFacts': [],
            'followUps': [],
          },
        ),
        'targetName': '미용실',
      }),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          callsRepositoryProvider.overrideWithValue(FakeCallsRepository(tasks)),
        ],
        child: const CallMateApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final manual = find.text('직접 입력하기');
    await tester.scrollUntilVisible(manual, 200, scrollable: find.byType(Scrollable).first);
    expect(manual, findsOneWidget);
    expect(
      DefaultTextStyle.of(tester.element(manual)).style.fontFamily,
      'packages/kolbi_ui/Pretendard',
    );
    // A RenderFlex overflow is reported as a FlutterError and fails the test here.
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('registerKolbiFontLicenses adds the Pretendard OFL text', (
    tester,
  ) async {
    registerKolbiFontLicenses();
    final entries = await tester.runAsync(
      () => LicenseRegistry.licenses.toList(),
    );
    final pretendard = entries!
        .where((e) => e.packages.contains('Pretendard'))
        .toList();
    expect(pretendard, hasLength(1));
    final text = pretendard.single.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('SIL OPEN FONT LICENSE'));
  });
}
