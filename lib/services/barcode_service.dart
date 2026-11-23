import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/nutrition.dart';

/// Hasil pencarian produk berdasarkan barcode.
class BarcodeProduct {
  const BarcodeProduct({
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.sugarG,
    required this.saltMg,
  });

  final String name;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double sugarG;
  final double saltMg;

  ParsedNutrition toParsed() => ParsedNutrition(
        name: name,
        calories: calories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        sugarG: sugarG,
        saltMg: saltMg,
        summary: 'Data gizi dari barcode produk.',
      );
}

/// Cari informasi gizi produk kemasan lewat barcode (OpenFoodFacts).
///
/// Gratis, tanpa API key, berbasis data produk dunia. Best-effort: bila
/// produk tidak ditemukan, mengembalikan null.
class BarcodeService {
  BarcodeService();

  static const _host = 'world.openfoodfacts.org';

  Future<BarcodeProduct?> lookup(String barcode) async {
    final uri = Uri.https(_host, '/api/v2/product/$barcode.json', {
      'fields': 'product_name,product_name_id,brands,nutriments',
    });
    try {
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'SonaSehat/1.0 (Flutter)'},
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if ((json['status'] as num?)?.toInt() != 1) return null;
      final product = json['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final name = (product['product_name_id'] as String?)?.trim().isNotEmpty ==
              true
          ? product['product_name_id'] as String
          : (product['product_name'] as String?) ?? '';
      if (name.trim().isEmpty) return null;

      final n = (product['nutriments'] as Map<String, dynamic>?) ?? const {};
      double val(String key) {
        final v = n[key];
        if (v is num) return v.toDouble();
        return double.tryParse('${v ?? ''}') ?? 0;
      }

      final kcal = val('energy-kcal_100g') != 0
          ? val('energy-kcal_100g')
          : val('energy-kcal_serving');
      return BarcodeProduct(
        name: name.trim(),
        calories: kcal.round(),
        proteinG: val('proteins_100g'),
        carbsG: val('carbohydrates_100g'),
        fatG: val('fat_100g'),
        sugarG: val('sugars_100g'),
        saltMg: val('salt_100g') * 1000,
      );
    } catch (_) {
      return null;
    }
  }
}
