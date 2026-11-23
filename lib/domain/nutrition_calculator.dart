/// Perhitungan target gizi dari profil pengguna.
///
/// Memakai rumus Mifflin-St Jeor untuk BMR (paling akurat untuk umum),
/// dikalikan faktor aktivitas menjadi TDEE, lalu disesuaikan dengan tujuan.
class NutritionCalculator {
  NutritionCalculator._();

  static const aktivitasFaktor = {
    'ringan': 1.375, // olahraga ringan 1-3x/minggu
    'sedang': 1.55, // olahraga sedang 3-5x/minggu
    'berat': 1.725, // olahraga berat 6-7x/minggu
  };

  static const tujuanFaktor = {
    'turun': 0.85, // defisit ~15%
    'jaga': 1.0,
    'naik': 1.15, // surplus ~15%
  };

  /// BMR (kkal/hari) dengan rumus Mifflin-St Jeor.
  static double bmr({
    required double beratKg,
    required int tinggiCm,
    required int umur,
    required String jenisKelamin,
  }) {
    final base = 10 * beratKg + 6.25 * tinggiCm - 5 * umur;
    return jenisKelamin == 'pria' ? base + 5 : base - 161;
  }

  /// TDEE (kkal/hari) = BMR x faktor aktivitas.
  static double tdee({
    required double beratKg,
    required int tinggiCm,
    required int umur,
    required String jenisKelamin,
    required String aktivitas,
  }) {
    final b = bmr(
      beratKg: beratKg,
      tinggiCm: tinggiCm,
      umur: umur,
      jenisKelamin: jenisKelamin,
    );
    return b * (aktivitasFaktor[aktivitas] ?? 1.375);
  }

  /// Target kalori harian (kkal) sesuai tujuan. Null bila data belum lengkap.
  static int? targetKalori({
    double? beratKg,
    int? tinggiCm,
    int? umur,
    String? jenisKelamin,
    String? aktivitas,
    String? tujuan,
  }) {
    if (beratKg == null ||
        tinggiCm == null ||
        umur == null ||
        jenisKelamin == null) {
      return null;
    }
    final t = tdee(
      beratKg: beratKg,
      tinggiCm: tinggiCm,
      umur: umur,
      jenisKelamin: jenisKelamin,
      aktivitas: aktivitas ?? 'ringan',
    );
    final f = tujuanFaktor[tujuan ?? 'jaga'] ?? 1.0;
    final target = (t * f).round();
    // Jaga batas aman minimum.
    return target < 1200 ? 1200 : target;
  }

  /// Perkiraan target air minum harian (ml) = 35 ml per kg berat.
  static int targetAirMl(double? beratKg) {
    if (beratKg == null || beratKg <= 0) return 2000;
    return (beratKg * 35).round();
  }

  /// Validasi data tubuh. Mengembalikan pesan error, atau null bila valid.
  static String? validateBody({
    required int? tinggiCm,
    required double? beratKg,
    required int? umur,
  }) {
    if (tinggiCm == null || tinggiCm < 80 || tinggiCm > 250) {
      return 'Tinggi harus antara 80–250 cm.';
    }
    if (beratKg == null || beratKg < 20 || beratKg > 300) {
      return 'Berat harus antara 20–300 kg.';
    }
    if (umur == null || umur < 5 || umur > 120) {
      return 'Umur harus antara 5–120 tahun.';
    }
    return null;
  }

  /// Validasi budget harian (Rp).
  static String? validateBudget(int? budgetIdr) {
    if (budgetIdr != null && (budgetIdr < 0 || budgetIdr > 100000000)) {
      return 'Budget harus antara Rp 0 – Rp 100.000.000.';
    }
    return null;
  }
}
