import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sona_ai/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('navigasi semua tab dan kirim chat ke AI', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SonaApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Lewati layar login opsional.
    final skip = find.text('Lewati dulu, pakai tanpa login');
    if (skip.evaluate().isEmpty) {
      await tester.scrollUntilVisible(skip, 200,
          scrollable: find.byType(Scrollable).first);
    }
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip);
      await tester.pumpAndSettle();
    }

    // Beranda
    expect(find.text('Pencapaian Nutrisi'), findsOneWidget);

    // Tab Menu
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Masak Praktis Anak Kos'), findsOneWidget);

    // Tab Catatan
    await tester.tap(find.text('Catatan'));
    await tester.pumpAndSettle();
    expect(find.text('Budget Makan Harian'), findsOneWidget);

    // Tab Tanya (Konsultasi)
    await tester.tap(find.text('Tanya'));
    await tester.pumpAndSettle();
    expect(find.text('Tanya Sona soal gizi & budget'), findsOneWidget);

    // Kirim pesan ke AI live (Worker)
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'Sebutkan 1 makanan tinggi protein, singkat.');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(seconds: 1));

    // Tunggu jawaban muncul (polling sampai 60 detik).
    var got = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
      final bubbles = find.byType(Text);
      final texts = tester
          .widgetList<Text>(bubbles)
          .map((t) => t.data ?? '')
          .where((s) =>
              s.length > 15 &&
              !s.contains('Tulis pertanyaanmu') &&
              !s.contains('Sebutkan 1 makanan'))
          .toList();
      if (texts.isNotEmpty) {
        got = true;
        debugPrint('JAWABAN_AI: ${texts.last}');
        break;
      }
    }
    expect(got, isTrue, reason: 'AI tidak membalas dalam 60 detik');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
