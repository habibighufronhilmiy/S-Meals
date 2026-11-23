import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sona_ai/main.dart';

void main() {
  testWidgets('Sona app builds bootstrap, login opsional, lalu home',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SonaApp());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Layar login muncul dulu, user boleh melewatinya.
    final skip = find.text('Lewati dulu, pakai tanpa login');
    if (skip.evaluate().isEmpty) {
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(skip, 300, scrollable: scroll);
    }
    expect(skip, findsOneWidget);
    await tester.tap(skip);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Beranda'), findsWidgets);
  });
}
