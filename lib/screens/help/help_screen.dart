import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/sona_components.dart';

class _FaqItem {
  const _FaqItem(this.question, this.answer);
  final String question;
  final String answer;
}

class _FaqSection {
  const _FaqSection(this.title, this.items);
  final String title;
  final List<_FaqItem> items;
}

/// Pusat bantuan berisi pertanyaan yang paling sering ditanyakan.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _search = TextEditingController();
  String _query = '';

  static const _sections = [
    _FaqSection('Memulai', [
      _FaqItem(
        "Apa itu S'Meals?",
        "S'Meals adalah pendamping makan anak kos. Kamu bisa memindai makanan, "
            'melihat perkiraan kalori dan gizi, mencatat pengeluaran makan, serta '
            'meminta ide menu hemat dari bahan yang ada.',
      ),
      _FaqItem(
        'Apakah wajib punya akun?',
        'Tidak. Semua fitur inti bisa dipakai tanpa login dan data tersimpan di '
            'HP. Login hanya diperlukan untuk mencadangkan catatan ke cloud dan '
            'menyinkronkan antar perangkat.',
      ),
      _FaqItem(
        'Bagaimana cara mengatur target kalori?',
        'Buka Beranda lalu ketuk "Ubah target". Isi target kalori dan budget '
            'harian. Kalau sudah login, kamu juga bisa memakai Profil & Target '
            'Gizi agar target dihitung otomatis dari tinggi, berat, umur, dan '
            'aktivitas.',
      ),
    ]),
      _FaqSection('Pindai Makanan', [
        _FaqItem('Bagaimana cara pakai pemindai?',
            'Arahkan kamera ke piring atau label kemasan. Sona akan memperkirakan gizi dan skor kesehatan.'),
        _FaqItem(
          'Kenapa hasil pindai bisa berbeda dengan aslinya?',
          'Angka gizi adalah perkiraan AI dari foto. Porsi, minyak, dan bahan '
              'tersembunyi tidak selalu terlihat. Gunakan hasilnya sebagai panduan, '
              'bukan angka pasti.',
        ),
      _FaqItem(
        'Cara memindai label nutrisi?',
        'Di tab Pindai pilih "Label Nutrisi", lalu foto bagian tabel informasi '
            'nilai gizi. Pastikan angka per sajian terlihat jelas dan tidak blur.',
      ),
      _FaqItem(
        'Kenapa tombol suara tidak otomatis berbunyi?',
        'Suara memang hanya aktif saat kamu menekan tombol "Dengarkan". Ini agar '
            'tidak mengganggu saat kamu memindai di tempat ramai.',
      ),
      _FaqItem(
        'Bisa mencatat tanpa foto?',
        'Bisa. Gunakan "Cari dari daftar" untuk mencari makanan yang sudah ada di '
            'database, atau "Pindai barcode" untuk produk kemasan.',
      ),
    ]),
    _FaqSection('Catatan & Budget', [
      _FaqItem(
        'Bagaimana cara melihat detail catatan?',
        'Buka tab Catatan, lalu ketuk salah satu makanan. Kamu akan melihat foto, '
            'ringkasan AI, tabel gizi lengkap, dan bisa mengubah waktu makan atau '
            'menghapus catatan.',
      ),
      _FaqItem(
        'Kenapa catatan tidak muncul di perangkat lain?',
        'Pastikan kamu login di kedua perangkat dan terhubung internet. Catatan '
            'akan tersinkron otomatis. Jika masih offline, catatan menunggu di '
            'antrean sinkron.',
      ),
      _FaqItem(
        'Bagaimana mengubah budget makan?',
        'Ketuk "Atur" pada kartu Budget Makan Harian di tab Catatan, atau ubah '
            'lewat "Ubah target" di Beranda.',
      ),
    ]),
    _FaqSection('Ide Menu', [
      _FaqItem(
        'Kenapa hasil menu tidak sesuai bahan saya?',
        'Tulis bahan dengan jumlah yang jelas, misalnya "telur 2 butir" atau '
            '"tahu 1 papan". Sona juga mendeteksi minuman: bahan seperti teh, '
            'susu, atau buah akan diracik menjadi minuman, bukan makanan berat.',
      ),
      _FaqItem(
        'Tips belanja di halaman Menu itu dari mana?',
        'Tips disusun langsung oleh AI dari bahan yang kamu masukkan, budget, dan '
            'alat masak yang dipilih. Tips baru muncul setelah kamu menekan '
            '"Racik Menu".',
      ),
    ]),
    _FaqSection('Akun & Privasi', [
      _FaqItem(
        'Bagaimana cara daftar atau masuk?',
        'Buka menu di kiri atas lalu pilih Akun. Kamu bisa masuk dengan Google, '
            'atau daftar memakai email dan password. Password disimpan '
            'terenkripsi (PBKDF2).',
      ),
      _FaqItem(
        'Apakah foto saya diunggah?',
        'Foto dikirim ke server AI hanya untuk dianalisis saat kamu memindai. '
            'Yang disimpan di catatan adalah thumbnail kecil agar riwayat tetap '
            'ringan.',
      ),
      _FaqItem(
        'Apakah saran S\'Meals pengganti dokter?',
        'Bukan. Semua perkiraan gizi dan saran bersifat edukatif. Untuk kondisi '
            'medis atau diet khusus, konsultasikan dengan ahli gizi atau dokter.',
      ),
    ]),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_FaqSection> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _sections;
    return _sections
        .map((s) => _FaqSection(
              s.title,
              s.items
                  .where((i) =>
                      i.question.toLowerCase().contains(q) ||
                      i.answer.toLowerCase().contains(q))
                  .toList(),
            ))
        .where((s) => s.items.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final sections = _filtered;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Bantuan & FAQ'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            SonaSpacing.margin, SonaSpacing.sm, SonaSpacing.margin, SonaSpacing.lg),
        children: [
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Cari pertanyaan...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SonaRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: SonaSpacing.md),
          if (sections.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: SonaSpacing.lg),
              child: SonaEmptyState(
                icon: Icons.help_outline,
                title: 'Pertanyaan tidak ditemukan',
                message: 'Coba kata kunci lain, misalnya "pindai" atau "budget".',
              ),
            )
          else
            for (final s in sections) ...[
              Padding(
                padding: const EdgeInsets.only(
                    top: SonaSpacing.sm, bottom: SonaSpacing.xs),
                child: Text(
                  s.title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                ),
              ),
              SonaCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < s.items.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: SonaSpacing.md),
                          childrenPadding: const EdgeInsets.fromLTRB(
                              SonaSpacing.md, 0, SonaSpacing.md, SonaSpacing.md),
                          iconColor: Theme.of(context).colorScheme.primary,
                          collapsedIconColor:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          title: Text(
                            s.items[i].question,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                s.items[i].answer,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: SonaSpacing.sm),
            ],
          const SizedBox(height: SonaSpacing.md),
          Text(
            "S'Meals • perkiraan AI, bukan nasihat medis.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
