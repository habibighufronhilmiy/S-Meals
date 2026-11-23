/// Rekomendasi menu yang cocok dengan sisa budget hari ini.
///
/// Logika murni (tanpa Flutter) agar mudah diuji: ambil daftar makanan dari
/// tabel master, saring yang harganya <= sisa budget, lalu urutkan berdasarkan
/// skor kecocokan: murah, gizi seimbang, dan tidak melewati sisa kalori.
class BudgetRecommender {
  const BudgetRecommender._();

  /// Satu rekomendasi makanan siap tampil.
  static List<FoodPick> pick({
    required List<Map<String, dynamic>> foods,
    required int? sisaBudget,
    int? sisaKalori,
    int max = 3,
  }) {
    if (foods.isEmpty) return const [];

    final out = <FoodPick>[];
    for (final f in foods) {
      final harga = (f['harga_idr'] as num?)?.round() ?? 0;
      if (sisaBudget != null && harga > sisaBudget) continue;

      final kalori = (f['kalori'] as num?)?.round() ?? 0;
      final protein = (f['protein_g'] as num?)?.toDouble() ?? 0;
      final gula = (f['gula_g'] as num?)?.toDouble() ?? 0;
      final garam = (f['garam_mg'] as num?)?.toDouble() ?? 0;

      var skor = 0.0;
      // Lebih murah -> lebih baik (relatif terhadap sisa budget).
      if (sisaBudget != null && sisaBudget > 0) {
        skor += (1 - harga / sisaBudget) * 40;
      }
      // Protein padat -> lebih baik (dianggap sampai 25 g).
      skor += (protein.clamp(0, 25) / 25) * 30;
      // Gula & garam rendah -> lebih baik.
      skor += (1 - (gula.clamp(0, 20) / 20)) * 15;
      skor += (1 - (garam.clamp(0, 1500) / 1500)) * 15;
      // Cocok dengan sisa kalori (tidak berlebihan).
      if (sisaKalori != null && sisaKalori > 0) {
        if (kalori > sisaKalori) {
          skor -= (kalori - sisaKalori) / 20.0;
        } else {
          skor += (1 - (sisaKalori - kalori) / sisaKalori) * 10;
        }
      }

      out.add(FoodPick(
        id: (f['id'] as num?)?.toInt() ?? 0,
        nama: f['nama'] as String? ?? 'Makanan',
        kalori: kalori,
        proteinG: protein,
        hargaIdr: harga,
        skor: skor,
      ));
    }

    out.sort((a, b) => b.skor.compareTo(a.skor));
    return out.take(max).toList();
  }
}

/// Hasil ringkas satu rekomendasi.
class FoodPick {
  const FoodPick({
    required this.id,
    required this.nama,
    required this.kalori,
    required this.proteinG,
    required this.hargaIdr,
    required this.skor,
  });

  final int id;
  final String nama;
  final int kalori;
  final double proteinG;
  final int hargaIdr;
  final double skor;
}
