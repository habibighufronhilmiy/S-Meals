import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sona_ai/data/sona_store.dart';
import 'package:sona_ai/domain/nutrition.dart';
import 'package:sona_ai/main.dart';
import 'package:sona_ai/services/ai_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pipeline scan foto: gambar -> worker vision -> parse -> skor',
      (tester) async {
    final bytes = (await rootBundle.load('assets/food_test.jpg'))
        .buffer
        .asUint8List();

    final ai = AiService();
    String answer = await ai.complete(
      prompt:
          'Tolong analisis foto makanan ini. Sebutkan nama, perkirakan kalori, '
          'protein, karbohidrat, lemak, gula, garam.\n\n'
          '${NutritionExtractor.instruction}',
      mode: AiMode.food,
      imageBase64: base64Encode(bytes),
      mimeType: 'image/jpeg',
    );

    // Sama seperti app: kalau blok JSON belum ada, coba sekali lagi.
    if (NutritionExtractor.parse(answer) == null) {
      answer = await ai.complete(
        prompt:
            'Tolong analisis foto makanan ini. Sebutkan nama, perkirakan kalori, '
            'protein, karbohidrat, lemak, gula, garam.\n\n'
            '${NutritionExtractor.instruction}\n'
            'PENTING: balasan WAJIB diakhiri blok JSON valid, jangan dikosongkan.',
        mode: AiMode.food,
        imageBase64: base64Encode(bytes),
        mimeType: 'image/jpeg',
      );
    }
    ai.dispose();

    debugPrint('SCAN_ANSWER: $answer');
    final display = NutritionExtractor.stripForDisplay(answer);
    final parsed = NutritionExtractor.parse(answer);

    debugPrint('SCAN_DISPLAY: $display');
    debugPrint('SCAN_PARSED: name=${parsed?.name} cal=${parsed?.calories} '
        'protein=${parsed?.proteinG} sugar=${parsed?.sugarG} salt=${parsed?.saltMg}');

    expect(display.trim(), isNotEmpty, reason: 'teks tampilan kosong');
    expect(parsed, isNotNull, reason: 'blok JSON gagal diparse');

    final score = MealScoring.score(
      calories: parsed!.calories,
      proteinG: parsed.proteinG,
      sugarG: parsed.sugarG,
      saltMg: parsed.saltMg,
    );
    final log = MealScoring.toMealLog(parsed);
    debugPrint('SCAN_SCORE: ${score.label} -> MealLog: ${log.name} ${log.calories}kkal');
    expect(log.calories, greaterThanOrEqualTo(0));
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('generator menu AI menghasilkan output', (tester) async {
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

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Racik Menu'));
    await tester.pump(const Duration(seconds: 1));

    var got = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((s) => s.contains('Rekomendasi Menu Sona'))
          .toList();
      if (texts.isNotEmpty) {
        got = true;
        break;
      }
    }
    expect(got, isTrue, reason: 'generator menu tidak menghasilkan output');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('budget & catatan: simpan meal, atur budget, hapus meal',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await SonaStore.open();

    final meal = MealScoring.toMealLog(ParsedNutrition(
      name: 'Nasi Telur',
      calories: 420,
      proteinG: 14,
      carbsG: 60,
      fatG: 12,
      sugarG: 4,
      saltMg: 500,
      summary: 'Makan siang hemat',
      priceIdr: 9000,
    ));
    await store.addMeal(meal);
    expect(store.loadMeals().length, 1);

    await store.setDailyBudgetIdr(30000);
    expect(store.dailyBudgetIdr, 30000);

    final summary = store.todaySummary();
    expect(summary.totalCalories, 420);
    expect(summary.totalSpentIdr, 9000);
    debugPrint('STORE_SUMMARY: cal=${summary.totalCalories} spent=${summary.totalSpentIdr}');

    await store.removeMeal(meal.id);
    expect(store.loadMeals().isEmpty, isTrue);
  });
}
