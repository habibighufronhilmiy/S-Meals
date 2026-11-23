/// Skor keseimbangan gizi sebuah makanan.
enum MealScore {
  a('A'),
  bPlus('B+'),
  b('B'),
  c('C');

  const MealScore(this.label);
  final String label;
}

/// Waktu makan.
enum MealTime {
  sarapan('sarapan', 'Sarapan', '06:00 - 10:59'),
  makanSiang('makan_siang', 'Makan Siang', '11:00 - 14:59'),
  makanMalam('makan_malam', 'Makan Malam', '17:00 - 21:59'),
  camilan('camilan', 'Camilan', 'lainnya');

  const MealTime(this.key, this.label, this.hint);
  final String key;
  final String label;
  final String hint;

  /// Tebak waktu makan dari jam sekarang.
  static MealTime fromHour(int hour) {
    if (hour >= 6 && hour <= 10) return MealTime.sarapan;
    if (hour >= 11 && hour <= 14) return MealTime.makanSiang;
    if (hour >= 17 && hour <= 21) return MealTime.makanMalam;
    return MealTime.camilan;
  }

  static MealTime fromKey(String? key) => MealTime.values.firstWhere(
        (m) => m.key == key,
        orElse: () => MealTime.camilan,
      );
}

/// Satu catatan makan yang tersimpan (hasil pindai atau input manual).
class MealLog {
  MealLog({
    required this.id,
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.sugarG,
    required this.saltG,
    required this.score,
    required this.createdAt,
    this.priceIdr,
    this.imagePath,
    this.imageThumb,
    this.waktuMakan = MealTime.camilan,
    this.summary,
  });

  final String id;
  final String name;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double sugarG;
  final double saltG;
  final MealScore score;
  final DateTime createdAt;
  final int? priceIdr;
  final String? imagePath;

  /// Thumbnail base64 JPEG (tanpa prefix data URI) untuk sinkron antar HP.
  final String? imageThumb;
  final MealTime waktuMakan;

  /// Ringkasan singkat dari AI saat makanan dipindai.
  final String? summary;

  /// Id baris di server (tabel meal_logs). Null bila belum tersinkron.
  int? serverId;

  /// Salinan dengan waktu makan berbeda.
  MealLog copyWith({MealTime? waktuMakan, String? imageThumb}) => MealLog(
        id: id,
        name: name,
        calories: calories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        sugarG: sugarG,
        saltG: saltG,
        score: score,
        createdAt: createdAt,
        priceIdr: priceIdr,
        imagePath: imagePath,
        imageThumb: imageThumb ?? this.imageThumb,
        waktuMakan: waktuMakan ?? this.waktuMakan,
        summary: summary,
      )..serverId = serverId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'calories': calories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'sugarG': sugarG,
        'saltG': saltG,
        'score': score.name,
        'createdAt': createdAt.toIso8601String(),
        'priceIdr': priceIdr,
        'imagePath': imagePath,
        'imageThumb': imageThumb,
        'waktuMakan': waktuMakan.key,
        'summary': summary,
        'serverId': serverId,
      };

  factory MealLog.fromJson(Map<String, dynamic> json) => MealLog(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Makanan',
        calories: (json['calories'] as num?)?.round() ?? 0,
        proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0,
        carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0,
        fatG: (json['fatG'] as num?)?.toDouble() ?? 0,
        sugarG: (json['sugarG'] as num?)?.toDouble() ?? 0,
        saltG: (json['saltG'] as num?)?.toDouble() ?? 0,
        score: MealScore.values.firstWhere(
          (s) => s.name == json['score'],
          orElse: () => MealScore.b,
        ),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        priceIdr: (json['priceIdr'] as num?)?.round(),
        imagePath: json['imagePath'] as String?,
        imageThumb: json['imageThumb'] as String?,
        waktuMakan: MealTime.fromKey(json['waktuMakan'] as String?),
        summary: json['summary'] as String?,
      )..serverId = (json['serverId'] as num?)?.toInt();

  /// Bentuk payload untuk endpoint POST /v1/meals (skema server).
  ///
  /// Catatan: foto penuh TIDAK pernah dikirim — hanya thumbnail kecil
  /// (256px, ~10-25KB) supaya hemat dan tetap muncul setelah login ulang.
  /// Path file lokal (`gambar_path`) sengaja tidak dikirim karena hanya
  /// berlaku di perangkat lama dan percuma disimpan di DB.
  Map<String, dynamic> toServerJson() => {
        'nama': name,
        'tanggal': createdAt.toIso8601String().substring(0, 10),
        'waktu_makan': waktuMakan.key,
        'kalori': calories,
        'protein_g': proteinG,
        'karbo_g': carbsG,
        'lemak_g': fatG,
        'gula_g': sugarG,
        'garam_mg': saltG * 1000,
        'harga_idr': priceIdr ?? 0,
        if (imageThumb != null) 'gambar_thumb': imageThumb,
      };

  /// Bangun MealLog dari baris server (meal_logs).
  factory MealLog.fromServer(Map<String, dynamic> row) {
    final created = DateTime.tryParse(
            (row['created_at'] as String? ?? '').replaceFirst(' ', 'T')) ??
        DateTime.now();
    return MealLog(
      id: 'srv-${row['id']}',
      name: row['nama'] as String? ?? 'Makanan',
      calories: (row['kalori'] as num?)?.round() ?? 0,
      proteinG: (row['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (row['karbo_g'] as num?)?.toDouble() ?? 0,
      fatG: (row['lemak_g'] as num?)?.toDouble() ?? 0,
      sugarG: (row['gula_g'] as num?)?.toDouble() ?? 0,
      saltG: (row['garam_mg'] as num?)?.toDouble() != null
          ? (row['garam_mg'] as num).toDouble() / 1000
          : 0,
      score: MealScore.b,
      createdAt: created,
      priceIdr: (row['harga_idr'] as num?)?.round(),
      imagePath: row['gambar_path'] as String?,
      imageThumb: row['gambar_thumb'] as String?,
      waktuMakan: MealTime.fromKey(row['waktu_makan'] as String?),
      summary: row['summary'] as String?,
    )..serverId = (row['id'] as num?)?.toInt();
  }
}

/// Ringkasan gizi satu hari.
class DailySummary {
  DailySummary({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalSugar,
    required this.totalSalt,
    required this.totalSpentIdr,
    required this.count,
  });

  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalSugar;
  final double totalSalt;
  final int totalSpentIdr;
  final int count;

  static DailySummary empty() => DailySummary(
        totalCalories: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFat: 0,
        totalSugar: 0,
        totalSalt: 0,
        totalSpentIdr: 0,
        count: 0,
      );

  /// Menjumlahkan daftar catatan (biasanya untuk hari ini).
  factory DailySummary.from(List<MealLog> logs) {
    var cal = 0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    var sugar = 0.0;
    var salt = 0.0;
    var spent = 0;
    for (final m in logs) {
      cal += m.calories;
      protein += m.proteinG;
      carbs += m.carbsG;
      fat += m.fatG;
      sugar += m.sugarG;
      salt += m.saltG;
      spent += m.priceIdr ?? 0;
    }
    return DailySummary(
      totalCalories: cal,
      totalProtein: protein,
      totalCarbs: carbs,
      totalFat: fat,
      totalSugar: sugar,
      totalSalt: salt,
      totalSpentIdr: spent,
      count: logs.length,
    );
  }
}
