import 'package:flutter/material.dart';

/// Pintasan prompt chat ala slash command (mis. `/ide`).
///
/// Saat user mengetik `/` di kolom chat, daftar ini ditampilkan dan bisa
/// dipilih untuk langsung mengirim prompt siap pakai ke Sona.
class ChatCommand {
  const ChatCommand({
    required this.name,
    required this.description,
    required this.icon,
    required this.prompt,
  });

  /// Nama tanpa garis miring, huruf kecil, tanpa spasi (mis. `hemat`).
  final String name;
  final String description;
  final IconData icon;
  final String prompt;

  String get slash => '/$name';
}

/// Katalog command bawaan Sona Sehat.
const List<ChatCommand> kChatCommands = [
  ChatCommand(
    name: 'ide',
    description: 'Ide menu hemat hari ini',
    icon: Icons.lightbulb_outline,
    prompt:
        'Berikan 3 ide menu makan hemat untuk anak kos hari ini, lengkap '
        'dengan perkiraan kalori dan harga di Indonesia.',
  ),
  ChatCommand(
    name: 'protein',
    description: 'Makanan tinggi protein murah',
    icon: Icons.fitness_center,
    prompt:
        'Rekomendasikan makanan tinggi protein yang murah dan mudah didapat '
        'anak kos. Sebutkan protein per porsi dan harganya.',
  ),
  ChatCommand(
    name: 'hemat',
    description: 'Menu di bawah Rp 15.000',
    icon: Icons.savings_outlined,
    prompt:
        'Beri menu makan yang totalnya di bawah Rp 15.000, tetap bergizi '
        'seimbang. Sertakan perkiraan kalori dan harganya.',
  ),
  ChatCommand(
    name: 'kalori',
    description: 'Hitung kalori makananku',
    icon: Icons.local_fire_department_outlined,
    prompt:
        'Tolong hitung perkiraan kalori, protein, karbohidrat, lemak, gula, '
        'dan garam makanan yang aku sebutkan. Kalau aku belum menyebut '
        'makanannya, tanya dulu makanan dan porsinya.',
  ),
  ChatCommand(
    name: 'label',
    description: 'Baca label kemasan',
    icon: Icons.qr_code_2,
    prompt:
        'Tolong bantu baca label kemasan. Jelaskan kandungan gula, garam, dan '
        'lemaknya per sajian dalam bahasa awam, lalu beri alternatif yang '
        'lebih sehat.',
  ),
  ChatCommand(
    name: 'camilan',
    description: 'Camilan sehat & murah',
    icon: Icons.cookie_outlined,
    prompt:
        'Beri 3 ide camilan sehat murah buat anak kos, rendah gula dan garam, '
        'beserta perkiraan kalori dan harganya.',
  ),
  ChatCommand(
    name: 'air',
    description: 'Target air minum harian',
    icon: Icons.water_drop_outlined,
    prompt:
        'Berapa target air minum harian yang pas untukku? Beri tips praktis '
        'biar nggak lupa minum selama di kos atau kuliah.',
  ),
  ChatCommand(
    name: 'sisa',
    description: 'Manfaatkan sisa budget',
    icon: Icons.account_balance_wallet_outlined,
    prompt:
        'Sisa budget makanku hari ini terbatas. Menu apa yang cocok biar tetap '
        'bergizi tanpa melebihi budget?',
  ),
  ChatCommand(
    name: 'banding',
    description: 'Bandingkan 2 makanan',
    icon: Icons.compare_arrows,
    prompt:
        'Bandingkan dua makanan dari sisi kalori, protein, gula, garam, dan '
        'harga. Mana yang lebih sehat dan lebih hemat? Kalau aku belum '
        'menyebut dua makanannya, tanya dulu.',
  ),
  ChatCommand(
    name: 'sarapan',
    description: 'Sarapan cepat & sehat',
    icon: Icons.wb_sunny_outlined,
    prompt:
        'Ide sarapan cepat dan sehat buat anak kos yang buru-buru, murah, dan '
        'mengenyangkan. Sertakan perkiraan kalori dan harganya.',
  ),
];

/// Cari command berdasarkan nama (tanpa garis miring). Null bila tak ada.
ChatCommand? findChatCommand(String name) {
  final key = name.toLowerCase().replaceAll('/', '').trim();
  for (final c in kChatCommands) {
    if (c.name == key) return c;
  }
  return null;
}

/// Filter command untuk query setelah `/`.
///
/// [query] kosong -> semua command. Cocokkan ke nama ATAU deskripsi.
List<ChatCommand> matchChatCommands(String query) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) return kChatCommands;
  return kChatCommands
      .where((c) =>
          c.name.contains(q) || c.description.toLowerCase().contains(q))
      .toList();
}

/// Ambil query slash dari isi kolom teks.
///
/// Mengembalikan query (tanpa `/`) bila teks diawali `/` dan belum ada spasi,
/// selain itu null (artinya panel command tidak perlu tampil).
String? slashQueryOf(String text) {
  if (!text.startsWith('/')) return null;
  if (text.contains(' ') || text.contains('\n')) return null;
  return text.substring(1);
}
