import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Membuat thumbnail JPEG yang sangat kecil dari sebuah foto, lalu
/// meng-encode-nya menjadi base64 (tanpa prefix data URI).
///
/// Dipakai untuk sinkron foto antar perangkat tanpa object storage:
/// ukuran ~256px sisi terpanjang, kualitas 60 -> biasanya 10-25 KB.
class ThumbnailService {
  const ThumbnailService._();

  static const int maxSide = 256;
  static const int quality = 60;

  /// Kembalikan base64 JPEG, atau null bila gagal (mis. data rusak).
  static String? toBase64Jpeg(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final thumb = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxSide)
          : img.copyResize(decoded, height: maxSide);
      final jpg = img.encodeJpg(thumb, quality: quality);
      return base64Encode(jpg);
    } catch (_) {
      return null;
    }
  }

  /// Ambil kembali bytes dari base64 (untuk ditampilkan).
  static Uint8List? fromBase64(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }
}
