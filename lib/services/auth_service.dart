import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'ai_config.dart';

/// Profil pengguna Sona (hasil login).
class SonaUser {
  const SonaUser({
    required this.id,
    required this.nama,
    this.email,
    this.foto,
    this.tinggiCm,
    this.beratKg,
    this.umur,
    this.jenisKelamin,
    this.aktivitas,
    this.tujuan,
    this.targetKalori = 2000,
    this.targetBudgetIdr = 30000,
  });

  final int id;
  final String nama;
  final String? email;
  final String? foto;
  final int? tinggiCm;
  final double? beratKg;
  final int? umur;
  final String? jenisKelamin; // 'pria' | 'wanita'
  final String? aktivitas; // 'ringan' | 'sedang' | 'berat'
  final String? tujuan; // 'turun' | 'jaga' | 'naik'
  final int targetKalori;
  final int targetBudgetIdr;

  factory SonaUser.fromJson(Map<String, dynamic> j) => SonaUser(
        id: (j['id'] as num).toInt(),
        nama: (j['nama'] as String?) ?? 'Pengguna Sona',
        email: j['email'] as String?,
        foto: j['foto'] as String?,
        tinggiCm: (j['tinggi_cm'] as num?)?.toInt(),
        beratKg: (j['berat_kg'] as num?)?.toDouble(),
        umur: (j['umur'] as num?)?.toInt(),
        jenisKelamin: j['jenis_kelamin'] as String?,
        aktivitas: j['aktivitas'] as String?,
        tujuan: j['tujuan'] as String?,
        targetKalori: (j['target_kalori'] as num?)?.toInt() ?? 2000,
        targetBudgetIdr: (j['target_budget_idr'] as num?)?.toInt() ?? 30000,
      );
}

class AuthException implements Exception {
  AuthException(this.message, {this.expired = false});
  final String message;

  /// True bila penyebabnya sesi/token kedaluwarsa (perlu login ulang).
  final bool expired;
  @override
  String toString() => message;
}

/// Menangani login Google + sesi JWT ke Worker Sona.
class AuthService {
  AuthService({GoogleSignIn? googleSignIn})
      : _google = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile'],
              serverClientId: AiConfig.googleServerClientId,
            );

  final GoogleSignIn _google;

  String? _token;
  SonaUser? _user;

  /// Dipanggil ketika server menyatakan sesi kedaluwarsa (401). UI dapat
  /// memakainya untuk membersihkan sesi & meminta login ulang.
  VoidCallback? onExpired;

  SonaUser? get user => _user;
  bool get isLoggedIn => _token != null && _user != null;

  Uri _uri(String path) => Uri.parse('${AiConfig.proxyBaseUrl}$path');

  Map<String, String> _headers({bool auth = true}) => {
        'content-type': 'application/json',
        if (auth && _token != null) 'authorization': 'Bearer $_token',
      };

  /// Bersihkan sesi & beri tahu UI bila token kedaluwarsa.
  Future<void> _handleExpired() async {
    _token = null;
    _user = null;
    try {
      await _google.signOut();
    } catch (_) {}
    onExpired?.call();
  }

  /// Lemparkan [AuthException]; bila 401 dari server, tandai expired.
  Future<void> _throwHttp(int status, String body, String fallback) async {
    if (status == 401) {
      await _handleExpired();
      throw AuthException('Sesi kamu sudah berakhir. Silakan masuk lagi.',
          expired: true);
    }
    throw AuthException('$fallback ($status).');
  }

  /// Login Google: ambil ID token lalu tukar dengan JWT Sona.
  Future<SonaUser> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) {
      throw AuthException('Login Google dibatalkan.');
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw AuthException('Tidak mendapat ID token dari Google.');
    }

    final res = await http
        .post(
          _uri('auth/google'),
          headers: _headers(auth: false),
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(AiConfig.requestTimeout);

    if (res.statusCode != 200) {
      throw AuthException('Server menolak login (${res.statusCode}).');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _token = data['token'] as String?;
    _user = SonaUser.fromJson(data['user'] as Map<String, dynamic>);
    return _user!;
  }

  /// Login/pendaftaran dengan email + password.
  ///
  /// [register] = true untuk membuat akun baru, false untuk masuk.
  Future<SonaUser> signInWithEmail({
    required String email,
    required String password,
    String? nama,
    bool register = false,
  }) async {
    final path = register ? 'auth/register' : 'auth/login';
    final res = await http
        .post(
          _uri(path),
          headers: _headers(auth: false),
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
            if (register && nama != null && nama.trim().isNotEmpty)
              'nama': nama.trim(),
          }),
        )
        .timeout(AiConfig.requestTimeout);

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw AuthException(
        (data?['error'] as String?) ?? 'Gagal (${res.statusCode}).',
      );
    }
    _token = data!['token'] as String?;
    _user = SonaUser.fromJson(data['user'] as Map<String, dynamic>);
    return _user!;
  }

  /// Pulihkan sesi dari token tersimpan (opsional).
  Future<SonaUser?> restore(String? token) async {
    if (token == null || token.isEmpty) return null;
    _token = token;
    try {
      final res = await http
          .get(_uri('auth/me'), headers: _headers())
          .timeout(AiConfig.requestTimeout);
      if (res.statusCode != 200) {
        _token = null;
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _user = SonaUser.fromJson(data['user'] as Map<String, dynamic>);
      return _user;
    } catch (_) {
      _token = null;
      return null;
    }
  }

  String? get token => _token;

  /// Perbarui profil (tinggi/berat/umur/aktivitas/tujuan/target).
  Future<SonaUser> updateProfile({
    String? nama,
    int? tinggiCm,
    double? beratKg,
    int? umur,
    String? jenisKelamin,
    String? aktivitas,
    String? tujuan,
    int? targetKalori,
    int? targetBudgetIdr,
  }) async {
    final res = await http
        .patch(
          _uri('auth/me'),
          headers: _headers(),
          body: jsonEncode({
            'nama': ?nama,
            'tinggi_cm': ?tinggiCm,
            'berat_kg': ?beratKg,
            'umur': ?umur,
            'jenis_kelamin': ?jenisKelamin,
            'aktivitas': ?aktivitas,
            'tujuan': ?tujuan,
            'target_kalori': ?targetKalori,
            'target_budget_idr': ?targetBudgetIdr,
          }),
        )
        .timeout(AiConfig.requestTimeout);
    if (res.statusCode != 200) {
      await _throwHttp(res.statusCode, res.body, 'Gagal menyimpan profil');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _user = SonaUser.fromJson(data['user'] as Map<String, dynamic>);
    return _user!;
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {}
    _token = null;
    _user = null;
  }

  /// Pemakaian AI hari ini (di server). Null bila gagal/tidak login.
  Future<int?> fetchUsageToday() async {
    if (_token == null) return null;
    try {
      final res = await http
          .get(_uri('usage'), headers: _headers())
          .timeout(AiConfig.requestTimeout);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['terpakai'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  /* ----------------------------- Data: /v1/meals ---------------------------- */
  /// Ambil catatan makan milik user dari server (untuk sinkron awal).
  Future<List<Map<String, dynamic>>> fetchMeals() async {
    if (_token == null) return const [];
    final res = await http
        .get(_uri('meals'), headers: _headers())
        .timeout(AiConfig.requestTimeout);
    if (res.statusCode != 200) {
      await _throwHttp(res.statusCode, res.body, 'Gagal memuat catatan');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['meals'] as List?) ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Kirim satu catatan makan ke server. Mengembalikan id server (bila ada).
  Future<int?> pushMeal(Map<String, dynamic> meal) async {
    if (_token == null) return null;
    final res = await http
        .post(_uri('meals'), headers: _headers(), body: jsonEncode(meal))
        .timeout(AiConfig.requestTimeout);
    if (res.statusCode != 201 && res.statusCode != 200) {
      await _throwHttp(res.statusCode, res.body, 'Gagal menyimpan catatan');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final row = data['meal'] as Map<String, dynamic>?;
    return (row?['id'] as num?)?.toInt();
  }

  /// Hapus catatan di server.
  Future<void> deleteMeal(int serverId) async {
    if (_token == null) return;
    final res = await http
        .delete(_uri('meals/$serverId'), headers: _headers())
        .timeout(AiConfig.requestTimeout);
    if (res.statusCode == 401) {
      await _handleExpired();
      throw AuthException('Sesi kamu sudah berakhir.', expired: true);
    }
  }
}
