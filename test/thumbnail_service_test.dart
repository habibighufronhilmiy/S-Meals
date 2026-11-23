import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sona_ai/services/thumbnail_service.dart';

void main() {
  group('ThumbnailService', () {
    test('mengecilkan gambar besar menjadi thumbnail kecil', () {
      final big = img.Image(width: 1200, height: 900);
      img.fill(big, color: img.ColorRgb8(120, 200, 90));
      final bytes = Uint8List.fromList(img.encodeJpg(big, quality: 90));

      final b64 = ThumbnailService.toBase64Jpeg(bytes);
      expect(b64, isNotNull);

      final out = ThumbnailService.fromBase64(b64);
      expect(out, isNotNull);
      expect(out!.length, lessThan(bytes.length));

      final decoded = img.decodeImage(out)!;
      expect(decoded.width, ThumbnailService.maxSide);
    });

    test('portrait memakai tinggi sebagai sisi terpanjang', () {
      final tall = img.Image(width: 400, height: 1000);
      final bytes = Uint8List.fromList(img.encodeJpg(tall, quality: 90));
      final b64 = ThumbnailService.toBase64Jpeg(bytes)!;
      final decoded = img.decodeImage(ThumbnailService.fromBase64(b64)!)!;
      expect(decoded.height, ThumbnailService.maxSide);
    });

    test('data rusak mengembalikan null, tidak melempar', () {
      expect(ThumbnailService.toBase64Jpeg(Uint8List.fromList([1, 2, 3])), isNull);
    });

    test('fromBase64 null/kosong mengembalikan null', () {
      expect(ThumbnailService.fromBase64(null), isNull);
      expect(ThumbnailService.fromBase64(''), isNull);
    });
  });
}
