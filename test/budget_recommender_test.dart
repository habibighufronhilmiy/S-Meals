import 'package:flutter_test/flutter_test.dart';
import 'package:sona_ai/domain/budget_recommender.dart';

void main() {
  final foods = [
    {
      'id': 1,
      'nama': 'Nasi Goreng',
      'kalori': 380,
      'protein_g': 8,
      'gula_g': 4,
      'garam_mg': 800,
      'harga_idr': 15000,
    },
    {
      'id': 2,
      'nama': 'Tempe Orek',
      'kalori': 220,
      'protein_g': 18,
      'gula_g': 3,
      'garam_mg': 500,
      'harga_idr': 8000,
    },
    {
      'id': 3,
      'nama': 'Steak Wagyu',
      'kalori': 700,
      'protein_g': 40,
      'gula_g': 1,
      'garam_mg': 300,
      'harga_idr': 250000,
    },
  ];

  group('BudgetRecommender', () {
    test('menyaring makanan yang melebihi sisa budget', () {
      final picks = BudgetRecommender.pick(foods: foods, sisaBudget: 10000);
      expect(picks.map((p) => p.nama), isNot(contains('Steak Wagyu')));
      expect(picks.map((p) => p.nama), isNot(contains('Nasi Goreng')));
      expect(picks.map((p) => p.nama), contains('Tempe Orek'));
    });

    test('mengurutkan protein padat & murah lebih dulu', () {
      final picks = BudgetRecommender.pick(foods: foods, sisaBudget: 20000);
      expect(picks.first.nama, 'Tempe Orek');
    });

    test('menghormati batas max', () {
      final picks = BudgetRecommender.pick(foods: foods, sisaBudget: 999999, max: 1);
      expect(picks.length, 1);
    });

    test('daftar kosong mengembalikan kosong', () {
      expect(BudgetRecommender.pick(foods: const [], sisaBudget: 10000), isEmpty);
    });

    test('tanpa sisa budget tetap memberi rekomendasi', () {
      final picks = BudgetRecommender.pick(foods: foods, sisaBudget: null);
      expect(picks, isNotEmpty);
    });
  });
}
