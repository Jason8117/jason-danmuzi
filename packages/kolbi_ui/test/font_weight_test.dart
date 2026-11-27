import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

// SPEC-DESIGN-001 sync-audit F1: FontWeight must drive the wght axis of the variable Pretendard font.
// A real axis change alters advance widths; synthetic emboldening or no change does not.
const _sample = '굵기 확인 Weight 0123';

double _width(TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: _sample, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  setUpAll(() async {
    // The family name must match the theme's `packages/kolbi_ui/Pretendard`, or text falls back to Ahem.
    final bytes = File('assets/fonts/PretendardVariable.ttf').readAsBytesSync();
    await (FontLoader(
      'packages/kolbi_ui/Pretendard',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  testWidgets('FontWeight changes the rendered width of the real font', (
    tester,
  ) async {
    const base = TextStyle(
      fontFamily: AppTheme.fontFamily,
      package: AppTheme.fontPackage,
      fontSize: 15,
    );
    final w400 = _width(base.copyWith(fontWeight: FontWeight.w400));
    final w600 = _width(base.copyWith(fontWeight: FontWeight.w600));
    final w700 = _width(base.copyWith(fontWeight: FontWeight.w700));
    // ignore: avoid_print
    print('Pretendard width w400=$w400 w600=$w600 w700=$w700');
    expect(w600, greaterThan(w400));
    expect(w700, greaterThan(w600));
    // Setting the wght axis explicitly gives the same width, so fontWeight drives the axis itself.
    final axis700 = _width(
      base.copyWith(fontVariations: const [FontVariation.weight(700)]),
    );
    expect(w700, moreOrLessEquals(axis700, epsilon: 0.01));
  });

  testWidgets('bodyMedium copyWith(fontWeight: w700) under AppTheme.light '
      'renders wider than w400', (tester) async {
    final regular = GlobalKey();
    final bold = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            final body = Theme.of(context).textTheme.bodyMedium!;
            return Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sample,
                    key: regular,
                    style: body.copyWith(fontWeight: FontWeight.w400),
                  ),
                  Text(
                    _sample,
                    key: bold,
                    style: body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    final style = tester.widget<Text>(find.byKey(bold)).style!;
    expect(style.fontFamily, 'packages/kolbi_ui/Pretendard');
    final w400 = tester.getSize(find.byKey(regular)).width;
    final w700 = tester.getSize(find.byKey(bold)).width;
    // ignore: avoid_print
    print('Theme bodyMedium width w400=$w400 w700=$w700');
    expect(w700, greaterThan(w400));
  });
}
