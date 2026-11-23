import 'dart:convert';

import '../models/meal_log.dart';

/// Hasil terstruktur yang dibaca dari jawaban AI.
class ParsedNutrition {
  ParsedNutrition({
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.sugarG,
    required this.saltMg,
    required this.summary,
    this.priceIdr,
  });

  final String name;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double sugarG;
  final double saltMg;
  final String summary;
  final int? priceIdr;
}

/// Membaca blok JSON mesin yang diminta dari model pada akhir jawaban:
///
///   [[SONA_JSON]]{"name":"...","calories":450,...}[[/SONA_JSON]]
///
/// Blok ini disembunyikan dari user; teks sebelum blok tetap ditampilkan.
class NutritionExtractor {
  static const open = '[[SONA_JSON]]';
  static const close = '[[/SONA_JSON]]';

  /// Instruksi yang ditempel ke prompt agar model menyertakan blok JSON.
  static const instruction =
      'Setelah jawabanmu, tulis satu baris data mesin persis dengan format ini '
      '(tanpa penjelasan tambahan):\n$open'
      '{"name":"nama singkat","calories":450,"protein_g":20,"carbs_g":60,'
      '"fat_g":12,"sugar_g":6,"salt_mg":500,"price_idr":12000,'
      '"summary":"ringkas 6-10 kata"}$close';

  /// Menghapus blok JSON dari teks yang ditampilkan ke user.
  static String stripForDisplay(String text) {
    final start = text.indexOf(open);
    if (start < 0) return text;
    return text.substring(0, start).trimRight();
  }

  static bool isComplete(String text) =>
      text.contains(open) && text.contains(close);

  /// True bila jawaban mengandung blok JSON yang setidaknya bisa diurai.
  static bool hasParsable(String text) => parse(text) != null;

  /// Mengurai blok JSON menjadi [ParsedNutrition]; null bila tidak valid.
  static ParsedNutrition? parse(String text) {
    final start = text.indexOf(open);
    final end = text.indexOf(close);
    if (start < 0 || end <= start) return null;
    final raw = text.substring(start + open.length, end).trim();
    try {
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      return ParsedNutrition(
        name: _str(obj['name']).isEmpty ? 'Makanan' : _str(obj['name']),
        calories: _int(obj['calories']),
        proteinG: _dbl(obj['protein_g']),
        carbsG: _dbl(obj['carbs_g']),
        fatG: _dbl(obj['fat_g']),
        sugarG: _dbl(obj['sugar_g']),
        saltMg: _dbl(obj['salt_mg']),
        priceIdr: _intOrNull(obj['price_idr']),
        summary: _str(obj['summary']),
      );
    } catch (_) {
      return null;
    }
  }

  static String _str(Object? v) => v == null ? '' : '$v'.trim();

  static int _int(Object? v) {
    if (v is num) return v.round();
    return int.tryParse('$v') ?? 0;
  }

  static int? _intOrNull(Object? v) {
    if (v is num) return v.round();
    return int.tryParse('$v');
  }

  static double _dbl(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }
}

/// Menghitung skor kesehatan ringkas (A/B+/B/C) dari komposisi gizi.
///
/// Dasar penilaian:
///  - Rasio protein terhadap kalori (makin tinggi makin baik).
///  - Kepadatan gula (>10 g/porsi mulai dikurangi).
///  - Kepadatan garam (>600 mg/porsi mulai dikurangi).
///  - Porsi kalori ekstrem (>800 kkal sekali makan dikurangi).
class MealScoring {
  MealScoring._();

  static MealScore score({
    required int calories,
    required double proteinG,
    required double sugarG,
    required double saltMg,
  }) {
    var points = 0;

    final proteinPer100 = calories > 0 ? proteinG / calories * 100 : 0.0;
    if (proteinPer100 >= 8) {
      points += 3;
    } else if (proteinPer100 >= 5) {
      points += 2;
    } else if (proteinPer100 >= 3) {
      points += 1;
    }

    if (sugarG <= 5) {
      points += 2;
    } else if (sugarG <= 10) {
      points += 1;
    }

    if (saltMg <= 300) {
      points += 2;
    } else if (saltMg <= 600) {
      points += 1;
    }

    if (calories >= 150 && calories <= 800) {
      points += 2;
    } else if (calories >= 1 && calories <= 1000) {
      points += 1;
    }

    if (points >= 8) return MealScore.a;
    if (points >= 6) return MealScore.bPlus;
    if (points >= 4) return MealScore.b;
    return MealScore.c;
  }

  /// Membuat [MealLog] dari hasil parse + skor otomatis.
  static MealLog toMealLog(
    ParsedNutrition parsed, {
    String? imagePath,
    String? imageThumb,
    MealTime? waktuMakan,
  }) {
    final score = MealScoring.score(
      calories: parsed.calories,
      proteinG: parsed.proteinG,
      sugarG: parsed.sugarG,
      saltMg: parsed.saltMg,
    );
    return MealLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: parsed.name,
      calories: parsed.calories,
      proteinG: parsed.proteinG,
      carbsG: parsed.carbsG,
      fatG: parsed.fatG,
      sugarG: parsed.sugarG,
      saltG: parsed.saltMg,
      score: score,
      createdAt: DateTime.now(),
      priceIdr: parsed.priceIdr,
      imagePath: imagePath,
      imageThumb: imageThumb,
      waktuMakan: waktuMakan ?? MealTime.fromHour(DateTime.now().hour),
      summary: parsed.summary.trim().isEmpty ? null : parsed.summary.trim(),
    );
  }

  static String formatGrams(double value) {
    final rounded = (value * 10).round() / 10.0;
    return rounded % 1.0 == 0.0 ? rounded.toInt().toString() : rounded.toString();
  }
}
