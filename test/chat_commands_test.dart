import 'package:flutter_test/flutter_test.dart';
import 'package:sona_ai/domain/chat_commands.dart';

void main() {
  group('matchChatCommands', () {
    test('query kosong mengembalikan semua command', () {
      expect(matchChatCommands('').length, kChatCommands.length);
    });

    test('cocok lewat nama', () {
      final r = matchChatCommands('prot');
      expect(r.map((c) => c.name), contains('protein'));
    });

    test('cocok lewat deskripsi (case-insensitive)', () {
      final r = matchChatCommands('SARAPAN');
      expect(r, isNotEmpty);
    });

    test('tidak ada yang cocok -> kosong', () {
      expect(matchChatCommands('zzz'), isEmpty);
    });
  });

  group('findChatCommand', () {
    test('menemukan command dan mengabaikan garis miring', () {
      expect(findChatCommand('/ide')?.name, 'ide');
      expect(findChatCommand('ide')?.name, 'ide');
    });

    test('null bila tidak ada', () {
      expect(findChatCommand('tidak-ada'), isNull);
    });
  });

  group('slashQueryOf', () {
    test('mendeteksi query setelah slash', () {
      expect(slashQueryOf('/'), '');
      expect(slashQueryOf('/pr'), 'pr');
    });

    test('null bila bukan slash atau sudah ada spasi', () {
      expect(slashQueryOf('hai'), isNull);
      expect(slashQueryOf('/kalori nasi'), isNull);
      expect(slashQueryOf('bukan/ini'), isNull);
    });
  });

  test('setiap command punya nama & prompt yang valid', () {
    for (final c in kChatCommands) {
      expect(c.name, isNotEmpty);
      expect(c.name.contains(' '), isFalse);
      expect(c.name.contains('/'), isFalse);
      expect(c.prompt, isNotEmpty);
      expect(c.description, isNotEmpty);
    }
  });
}
