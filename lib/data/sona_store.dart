import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/budget_recommender.dart';
import '../models/meal_log.dart';
import '../services/auth_service.dart';
import '../services/food_service.dart';

/// Penyimpanan lokal sederhana berbasis SharedPreferences.
///
/// Menyimpan daftar catatan makan, nama pengguna, target kalori, dan budget
/// harian. Ringan dan cukup untuk skala aplikasi harian.
///
/// Bila user sudah login (`attachAuth`), setiap perubahan catatan ikut
/// disinkronkan ke server (Cloudflare D1) secara best-effort.
class SonaStore {
  SonaStore(this._prefs);

  final SharedPreferences _prefs;
  AuthService? _auth;
  final FoodService _foods = const FoodService();

  /// Cache tabel master makanan (diisi saat memuat rekomendasi budget).
  List<Map<String, dynamic>> _foodCache = const [];

  /// Status sinkron terakhir: null = belum pernah, true = sukses, false = gagal.
  bool? lastSyncOk;
  DateTime? lastSyncAt;

  /// Jumlah catatan yang belum tersinkron ke server (serverId == null).
  int get pendingSyncCount => loadMeals().where((m) => m.serverId == null).length;

  /// True bila auth sudah terpasang dan user sedang login.
  bool get isAuthAttached => _auth?.isLoggedIn ?? false;

  static const _keyMeals = 'sona_meals';
  static const _keyName = 'sona_display_name';
  static const _keyCalorieTarget = 'sona_calorie_target';
  static const _keyBudget = 'sona_daily_budget';
  static const _keyStreak = 'sona_streak';
  static const _keyLastLogDay = 'sona_last_log_day';
  static const _keyChat = 'sona_chat_history';
  static const _keyAuthToken = 'sona_auth_token';
  static const _keyWater = 'sona_water_log';
  static const _keyWeightKg = 'sona_weight_kg';
  static const _keyReminders = 'sona_reminders_enabled';
  static const _keyReminderTimes = 'sona_reminder_times';
  static const _keyThemeMode = 'sona_theme_mode';

  /// Jam pengingat bawaan per kunci: 'sarapan', 'siang', 'malam', 'air'.
  static const Map<String, String> defaultReminderTimes = {
    'sarapan': '07:00',
    'siang': '12:30',
    'malam': '19:00',
    'air': '10:00',
  };

  static Future<SonaStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return SonaStore(prefs);
  }

  List<MealLog> loadMeals() {
    final raw = _prefs.getStringList(_keyMeals) ?? const [];
    final meals = <MealLog>[];
    for (final item in raw) {
      try {
        meals.add(MealLog.fromJson(jsonDecode(item) as Map<String, dynamic>));
      } catch (_) {
        // Lewati entri rusak.
      }
    }
    meals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return meals;
  }

  Future<void> saveMeals(List<MealLog> meals) async {
    final raw = meals.map((m) => jsonEncode(m.toJson())).toList();
    await _prefs.setStringList(_keyMeals, raw);
  }

  Future<void> addMeal(MealLog meal) async {
    final meals = loadMeals()..insert(0, meal);
    await saveMeals(meals);
    await _bumpStreak();
    await _pushMeal(meal);
  }

  Future<void> removeMeal(String id) async {
    final meals = loadMeals();
    final target = meals.where((m) => m.id == id).toList();
    meals.removeWhere((m) => m.id == id);
    await saveMeals(meals);
    final auth = _auth;
    if (auth != null && target.isNotEmpty && target.first.serverId != null) {
      try {
        await auth.deleteMeal(target.first.serverId!);
      } catch (_) {
        // Offline: abaikan, akan tersinkron lain waktu.
      }
    }
  }

  /// Hubungkan layanan auth supaya catatan ikut disinkron ke server.
  void attachAuth(AuthService auth) => _auth = auth;

  Future<void> _pushMeal(MealLog meal) async {
    final auth = _auth;
    if (auth == null || !auth.isLoggedIn) return;
    try {
      final serverId = await auth.pushMeal(meal.toServerJson());
      if (serverId != null) {
        meal.serverId = serverId;
        final meals = loadMeals();
        final idx = meals.indexWhere((m) => m.id == meal.id);
        if (idx >= 0) {
          meals[idx].serverId = serverId;
          await saveMeals(meals);
        }
      }
    } catch (_) {
      // Offline: catatan tetap tersimpan lokal.
    }
  }

  /// Sinkron awal: gabungkan catatan server ke lokal (tanpa duplikat).
  ///
  /// Duplikat dicek lewat `serverId`: catatan yang sudah pernah di-push dari
  /// perangkat ini (id lokal asli + serverId) tidak boleh masuk lagi sebagai
  /// baris baru berawalan 'srv-'.
  Future<void> syncFromServer() async {
    final auth = _auth;
    if (auth == null || !auth.isLoggedIn) return;
    try {
      final rows = await auth.fetchMeals();
      final local = loadMeals();
      final ids = local.map((m) => m.id).toSet();
      final serverIds =
          local.map((m) => m.serverId).whereType<int>().toSet();
      for (final row in rows) {
        final mapped = MealLog.fromServer(row);
        final sid = mapped.serverId;
        if (sid != null && serverIds.contains(sid)) continue;
        if (ids.contains(mapped.id)) continue;
        local.add(mapped);
        ids.add(mapped.id);
        if (sid != null) serverIds.add(sid);
      }
      local.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await saveMeals(local);
      lastSyncOk = true;
      lastSyncAt = DateTime.now();
    } catch (_) {
      lastSyncOk = false;
      lastSyncAt = DateTime.now();
      // Offline: tetap pakai data lokal.
    }
  }

  /// Tarik ulang dari server + kirim catatan yang belum tersinkron.
  ///
  /// Dipakai saat membuka layar catatan supaya data antar HP selalu segar.
  Future<void> refreshFromServer() async {
    final auth = _auth;
    if (auth == null || !auth.isLoggedIn) return;
    try {
      // Kirim dulu catatan lokal yang belum punya serverId.
      for (final m in loadMeals().where((m) => m.serverId == null)) {
        await _pushMeal(m);
      }
      await syncFromServer();
    } catch (_) {
      lastSyncOk = false;
      lastSyncAt = DateTime.now();
    }
  }

  List<MealLog> todayMeals() {
    final now = DateTime.now();
    return loadMeals()
        .where((m) =>
            m.createdAt.year == now.year &&
            m.createdAt.month == now.month &&
            m.createdAt.day == now.day)
        .toList();
  }

  DailySummary todaySummary() => DailySummary.from(todayMeals());

  /// Catatan pada tanggal tertentu (hari diabaikan jamnya).
  List<MealLog> mealsOn(DateTime day) => loadMeals()
      .where((m) =>
          m.createdAt.year == day.year &&
          m.createdAt.month == day.month &&
          m.createdAt.day == day.day)
      .toList();

  /// Ringkasan gizi pada tanggal tertentu.
  DailySummary summaryOn(DateTime day) => DailySummary.from(mealsOn(day));

  /// Kelompokkan catatan hari ini per waktu makan.
  Map<MealTime, List<MealLog>> todayByMealTime() {
    final out = <MealTime, List<MealLog>>{
      for (final t in MealTime.values) t: <MealLog>[],
    };
    for (final m in todayMeals()) {
      out[m.waktuMakan]!.add(m);
    }
    return out;
  }

  /// Set tanggal (yyyy-mm-dd) yang punya minimal satu catatan.
  Set<String> loggedDays() => loadMeals().map((m) => _dayKey(m.createdAt)).toSet();

  /// Ubah waktu makan sebuah catatan (lokal + best-effort ke server).
  Future<void> setMealTime(String id, MealTime time) async {
    final meals = loadMeals();
    final idx = meals.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    meals[idx] = meals[idx].copyWith(waktuMakan: time);
    await saveMeals(meals);
  }

  String get displayName => _prefs.getString(_keyName) ?? '';

  Future<void> setDisplayName(String value) =>
      _prefs.setString(_keyName, value);

  int get calorieTarget => _prefs.getInt(_keyCalorieTarget) ?? 2000;

  Future<void> setCalorieTarget(int value) =>
      _prefs.setInt(_keyCalorieTarget, value);

  /// Berat badan terakhir (kg) dari profil, untuk hitung target air.
  double? get lastWeightKg => _prefs.getDouble(_keyWeightKg);

  Future<void> setWeightKg(double? value) async {
    if (value == null) {
      await _prefs.remove(_keyWeightKg);
    } else {
      await _prefs.setDouble(_keyWeightKg, value);
    }
  }

  int get dailyBudgetIdr => _prefs.getInt(_keyBudget) ?? 0;

  /// Sisa budget hari ini = budget - total pengeluaran hari ini (>= 0).
  /// Mengembalikan null bila user belum mengatur budget.
  int? get budgetSisaIdr {
    final budget = dailyBudgetIdr;
    if (budget <= 0) return null;
    final spent = todaySummary().totalSpentIdr;
    return (budget - spent).clamp(0, budget);
  }

  /// Muat ulang tabel master makanan untuk rekomendasi budget (best-effort).
  Future<void> refreshFoods() async {
    try {
      _foodCache = await _foods.list();
    } catch (_) {
      // Abaikan; rekomendasi cukup tidak tampil bila gagal.
    }
  }

  /// Rekomendasi menu yang cocok dengan sisa budget & sisa kalori hari ini.
  List<FoodPick> budgetPicks({int max = 3}) {
    if (_foodCache.isEmpty) return const [];
    final sisaKalori = (calorieTarget - todaySummary().totalCalories).clamp(0, 1 << 30);
    return BudgetRecommender.pick(
      foods: _foodCache,
      sisaBudget: budgetSisaIdr,
      sisaKalori: sisaKalori,
      max: max,
    );
  }

  Future<void> setDailyBudgetIdr(int value) =>
      _prefs.setInt(_keyBudget, value);

  int get streak => _prefs.getInt(_keyStreak) ?? 0;

  /// Menambah streak harian bila ini catatan pertama hari ini.
  Future<void> _bumpStreak() async {
    final today = _dayKey(DateTime.now());
    final last = _prefs.getString(_keyLastLogDay);
    if (last == today) return;
    final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    final current = streak;
    final next = last == yesterday ? current + 1 : 1;
    await _prefs.setInt(_keyStreak, next);
    await _prefs.setString(_keyLastLogDay, today);
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Map<String, String>> loadChat() {
    final raw = _prefs.getStringList(_keyChat) ?? const [];
    final out = <Map<String, String>>[];
    for (final item in raw) {
      try {
        out.add(Map<String, String>.from(jsonDecode(item) as Map));
      } catch (_) {
        // Lewati entri rusak.
      }
    }
    return out;
  }

  Future<void> saveChat(List<Map<String, String>> messages) async {
    final raw = messages.map((m) => jsonEncode(m)).toList();
    await _prefs.setStringList(_keyChat, raw);
  }

  String? loadAuthToken() => _prefs.getString(_keyAuthToken);

  Future<void> saveAuthToken(String? token) async {
    if (token == null) {
      await _prefs.remove(_keyAuthToken);
    } else {
      await _prefs.setString(_keyAuthToken, token);
    }
  }

  /// Apakah pengingat (notifikasi) aktif.
  bool get remindersEnabled => _prefs.getBool(_keyReminders) ?? false;

  Future<void> setRemindersEnabled(bool value) =>
      _prefs.setBool(_keyReminders, value);

  /// Jam pengingat tersimpan ('HH:mm') per kunci, gabungan dengan default.
  Map<String, String> get reminderTimes {
    final raw = _prefs.getString(_keyReminderTimes);
    final out = Map<String, String>.from(defaultReminderTimes);
    if (raw != null) {
      try {
        final map = Map<String, String>.from(jsonDecode(raw) as Map);
        out.addAll(map);
      } catch (_) {
        // Lewati data rusak; pakai default.
      }
    }
    return out;
  }

  /// Simpan jam pengingat untuk satu kunci ('sarapan'|'siang'|'malam'|'air').
  Future<void> setReminderTime(String key, String hhmm) async {
    final out = reminderTimes;
    out[key] = hhmm;
    await _prefs.setString(_keyReminderTimes, jsonEncode(out));
  }

  /// Mode tema tersimpan: 'system' | 'light' | 'dark'.
  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'system';

  Future<void> setThemeMode(String value) =>
      _prefs.setString(_keyThemeMode, value);

  /// Hapus SEMUA data akun dari penyimpanan lokal (dipakai saat logout
  /// atau sesi kedaluwarsa) supaya tidak tercampur dengan akun lain.
  ///
  /// Preferensi perangkat (tema, pengingat) tetap disimpan.
  Future<void> clearAccountData() async {
    await Future.wait([
      _prefs.remove(_keyMeals),
      _prefs.remove(_keyChat),
      _prefs.remove(_keyName),
      _prefs.remove(_keyCalorieTarget),
      _prefs.remove(_keyBudget),
      _prefs.remove(_keyStreak),
      _prefs.remove(_keyLastLogDay),
      _prefs.remove(_keyAuthToken),
      _prefs.remove(_keyWater),
      _prefs.remove(_keyWeightKg),
    ]);
    _foodCache = const [];
    lastSyncOk = null;
    lastSyncAt = null;
  }

  // ---- Air minum (#8) ----

  /// Jumlah air minum hari ini (ml).
  int get waterTodayMl {
    final raw = _prefs.getString(_keyWater) ?? '';
    if (raw.isEmpty) return 0;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return (map[_dayKey(DateTime.now())] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Sisa air minum yang disarankan hari ini (ml).
  int waterForDay(DateTime day) {
    final raw = _prefs.getString(_keyWater) ?? '';
    if (raw.isEmpty) return 0;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return (map[_dayKey(day)] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Tambah air minum hari ini. Nilai boleh negatif untuk koreksi.
  Future<void> addWaterMl(int ml) async {
    final raw = _prefs.getString(_keyWater) ?? '';
    Map<String, dynamic> map;
    try {
      map = raw.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      map = <String, dynamic>{};
    }
    final key = _dayKey(DateTime.now());
    final next = ((map[key] as num?)?.toInt() ?? 0) + ml;
    map[key] = next < 0 ? 0 : next;
    await _prefs.setString(_keyWater, jsonEncode(map));
  }

  /// Data serat (gram) harian dari catatan makan.
  double fiberTodayG() {
    // Perkiraan serat dihitung dari karbo kompleks; disederhanakan.
    return todaySummary().totalCarbs * 0.08;
  }

  /// Ringkasan harian untuk [days] hari terakhir (terlama → terbaru).
  List<DailySummary> recentDays(int days) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final day = DateTime(now.year, now.month, now.day - (days - 1 - i));
      return summaryOn(day);
    });
  }

  /// Air minum untuk [days] hari terakhir (ml, terlama → terbaru).
  List<int> recentWater(int days) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final day = DateTime(now.year, now.month, now.day - (days - 1 - i));
      return waterForDay(day);
    });
  }
}
