/// Perapi teks jawaban AI agar enak dibaca di layar kecil.
///
/// Model sering menambahkan penanda markdown (`**`, `#`, backtick) dan emoji
/// yang membuat jawaban terasa ramai. Kelas ini membersihkannya tanpa
/// menghilangkan isi jawaban.
class SonaText {
  SonaText._();

  static final _jsonBlock =
      RegExp(r'\[\[SONA_JSON\]\][\s\S]*?\[\[/SONA_JSON\]\]');
  static final _menuBlock =
      RegExp(r'\[\[SONA_MENU\]\][\s\S]*?\[\[/SONA_MENU\]\]');
  static final _emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]',
    unicode: true,
  );
  static final _heading = RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true);
  static final _quote = RegExp(r'^\s{0,3}>\s?', multiLine: true);
  static final _bullet = RegExp(r'^\s*[-*+]\s+', multiLine: true);
  static final _pipeRow = RegExp(r'^[ \t]*\|.*\|[ \t]*$', multiLine: true);
  static final _pipeCellJunk = RegExp(r'^[-=_:.\s]+$');
  // Baris separator/garis mendatar: minimal 3 tanda -, =, _, ~, :, .
  // berturut (boleh berselang spasi) — contoh: `---- --------- ---`.
  static final _ruleRow =
      RegExp(r'^[ \t]*(?:[-=_~:.]{3,}[ \t]*)+$', multiLine: true);

  /// Bersihkan jawaban AI: buang blok mesin, markdown, dan emoji berlebih.
  static String cleanAi(String input) {
    var s = input;
    // Saat jawaban masih streaming, penutup blok mesin belum tentu datang.
    for (final token in const ['[[SONA_JSON]]', '[[SONA_MENU]]']) {
      final idx = s.indexOf(token);
      if (idx >= 0) s = s.substring(0, idx);
    }
    s = s.replaceAll(_jsonBlock, '');
    s = s.replaceAll(_menuBlock, '');
    s = s.replaceAll('```', '');

    // Baris tabel markdown (diawari & diakhiri pipe): rapikan jadi teks
    // runtuh SEBELUM pipe dibuang, supaya baris separator ikut terbuang.
    s = s.replaceAllMapped(_pipeRow, (m) {
      final cells = m
          .group(0)!
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      if (cells.isEmpty) return '';
      // Baris pemisah kolom (--- === :) dibuang total.
      if (cells.every((c) => _pipeCellJunk.hasMatch(c))) return '';
      return cells.join(' · ');
    });

    s = s.replaceAll(_heading, '');
    s = s.replaceAll(_quote, '');
    s = s.replaceAll(_bullet, '• ');
    s = s.replaceAll('**', '');
    s = s.replaceAll('__', '');
    s = s.replaceAll('~~', '');
    s = s.replaceAll('`', '');
    s = s.replaceAll('*', '');
    s = s.replaceAll(_emoji, '');
    // Sisa pipe (mis. baris multi-baris) -> spasi biasa.
    s = s.replaceAll(RegExp(r'[|┃]'), ' ');
    // Buang sisa garis pemisah: ---, ====, ____, atau campuran berselang.
    s = s.replaceAll(_ruleRow, '');
    s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  /// Ambil beberapa kalimat pertama untuk ringkasan singkat.
  static String firstSentences(String text, {int maxSentences = 2}) {
    final clean = cleanAi(text);
    if (clean.isEmpty) return '';
    final parts = clean.split(RegExp(r'(?<=[.!?])\s+'));
    return parts.take(maxSentences).join(' ').trim();
  }
}
