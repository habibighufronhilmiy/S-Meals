import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sona_ai/data/sona_store.dart';
import 'package:sona_ai/screens/scan/food_search_screen.dart';
import 'package:sona_ai/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cari makanan dari tabel master lalu tambah ke catatan',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await SonaStore.open();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: FoodSearchScreen(store: store),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Cari "nasi" (endpoint /v1/foods?q=nasi).
    await tester.enterText(find.byType(TextField).first, 'nasi');
    await tester.pump(const Duration(milliseconds: 400));

    // Tunggu hasil dari server.
    var found = false;
    for (var i = 0; i < 20; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      if (find.text('Nasi Goreng').evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }
    expect(found, isTrue, reason: 'hasil pencarian tidak muncul dari server');

    // Tambahkan ke catatan.
    final addBtn = find.byIcon(Icons.add).first;
    await tester.tap(addBtn);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(store.loadMeals().isNotEmpty, isTrue,
        reason: 'makanan tidak masuk ke catatan lokal');
    debugPrint('SEARCH_ADDED: ${store.loadMeals().first.name} '
        '${store.loadMeals().first.calories}kkal');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
