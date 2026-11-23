import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_config.dart';

/// Klien tabel master makanan (`GET /v1/foods`).
class FoodService {
  const FoodService();

  /// Ambil daftar makanan, opsional dengan kata kunci [q].
  Future<List<Map<String, dynamic>>> list({String q = ''}) async {
    final uri = Uri.parse(
        '${AiConfig.proxyBaseUrl}foods?q=${Uri.encodeQueryComponent(q)}');
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Server membalas ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['foods'] as List?) ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
}
