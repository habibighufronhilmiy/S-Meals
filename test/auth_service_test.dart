import 'package:flutter_test/flutter_test.dart';
import 'package:sona_ai/services/auth_service.dart';

void main() {
  group('SonaUser.fromJson', () {
    test('membaca field lengkap', () {
      final u = SonaUser.fromJson({
        'id': 7,
        'nama': 'Budi',
        'email': 'budi@contoh.com',
        'foto': 'https://x/y.png',
        'tinggi_cm': 170,
        'berat_kg': 65.5,
        'umur': 22,
        'jenis_kelamin': 'pria',
        'aktivitas': 'sedang',
        'tujuan': 'turun',
        'target_kalori': 2100,
        'target_budget_idr': 25000,
      });
      expect(u.id, 7);
      expect(u.nama, 'Budi');
      expect(u.tinggiCm, 170);
      expect(u.beratKg, 65.5);
      expect(u.umur, 22);
      expect(u.targetKalori, 2100);
      expect(u.targetBudgetIdr, 25000);
    });

    test('memberi nilai default bila field kosong', () {
      final u = SonaUser.fromJson({'id': 1, 'nama': 'Anon'});
      expect(u.targetKalori, 2000);
      expect(u.targetBudgetIdr, 30000);
      expect(u.tinggiCm, isNull);
      expect(u.beratKg, isNull);
    });
  });

  group('AuthException', () {
    test('menandai sesi kedaluwarsa', () {
      final e = AuthException('habis', expired: true);
      expect(e.expired, isTrue);
      expect(e.toString(), 'habis');
    });

    test('default bukan expired', () {
      expect(AuthException('x').expired, isFalse);
    });
  });
}
