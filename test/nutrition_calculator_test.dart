import 'package:flutter_test/flutter_test.dart';
import 'package:sona_ai/domain/nutrition_calculator.dart';

void main() {
  group('NutritionCalculator', () {
    test('BMR pria memakai Mifflin-St Jeor', () {
      final b = NutritionCalculator.bmr(
        beratKg: 70,
        tinggiCm: 175,
        umur: 25,
        jenisKelamin: 'pria',
      );
      // 10*70 + 6.25*175 - 5*25 + 5 = 1673.75
      expect(b, closeTo(1673.75, 0.01));
    });

    test('BMR wanita memakai konstanta -161', () {
      final b = NutritionCalculator.bmr(
        beratKg: 60,
        tinggiCm: 160,
        umur: 25,
        jenisKelamin: 'wanita',
      );
      // 10*60 + 6.25*160 - 5*25 - 161 = 1314
      expect(b, closeTo(1314.0, 0.01));
    });

    test('target kalori null bila data belum lengkap', () {
      expect(
        NutritionCalculator.targetKalori(beratKg: 70, tinggiCm: 175),
        isNull,
      );
    });

    test('tujuan turun BB menurunkan target', () {
      final jaga = NutritionCalculator.targetKalori(
        beratKg: 70,
        tinggiCm: 175,
        umur: 25,
        jenisKelamin: 'pria',
        aktivitas: 'sedang',
        tujuan: 'jaga',
      );
      final turun = NutritionCalculator.targetKalori(
        beratKg: 70,
        tinggiCm: 175,
        umur: 25,
        jenisKelamin: 'pria',
        aktivitas: 'sedang',
        tujuan: 'turun',
      );
      expect(turun!, lessThan(jaga!));
    });

    test('target kalori tidak di bawah batas aman 1200', () {
      final t = NutritionCalculator.targetKalori(
        beratKg: 40,
        tinggiCm: 150,
        umur: 60,
        jenisKelamin: 'wanita',
        aktivitas: 'ringan',
        tujuan: 'turun',
      );
      expect(t!, greaterThanOrEqualTo(1200));
    });

    test('target air minum = 35 ml/kg', () {
      expect(NutritionCalculator.targetAirMl(60), 2100);
      expect(NutritionCalculator.targetAirMl(null), 2000);
    });
  });
}
