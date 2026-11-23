import 'dart:convert';

/// Satu racikan menu dari AI.
class MenuItem {
  const MenuItem({
    required this.name,
    required this.type,
    required this.costIdr,
    required this.calories,
    required this.proteinG,
    required this.ingredients,
    required this.steps,
    required this.note,
  });

  final String name;
  final String type;
  final int costIdr;
  final int calories;
  final double proteinG;
  final List<String> ingredients;
  final List<String> steps;
  final String note;

  bool get isDrink => type.toLowerCase().contains('minum');
}

/// Kumpulan menu + tips belanja yang dihasilkan AI.
class MenuPlan {
  const MenuPlan({
    required this.items,
    required this.shoppingTips,
    required this.displayText,
  });

  final List<MenuItem> items;
  final List<String> shoppingTips;
  final String displayText;

  factory MenuPlan.from(String answer, MenuPlan? parsed) {
    if (parsed != null) return parsed;
    return MenuPlan(
      items: const [],
      shoppingTips: const [],
      displayText: answer,
    );
  }
}

/// Membaca blok mesin menu:
///
///   [[SONA_MENU]]{"items":[...],"tips_belanja":[...]}[[/SONA_MENU]]
class MenuPlanExtractor {
  static const open = '[[SONA_MENU]]';
  static const close = '[[/SONA_MENU]]';

  static const instruction =
      'Akhiri jawabanmu dengan satu baris data mesin TANPA penjelasan lain, '
      'persis format ini:\n$open'
      '{"items":[{"name":"nama menu","type":"makanan atau minuman",'
      '"cost_idr":8000,"calories":350,"protein_g":18,'
      '"bahan":["bahan 1","bahan 2"],"langkah":["langkah 1","langkah 2"],'
      '"catatan":"satu kalimat kenapa cocok"}],'
      '"tips_belanja":["tips 1","tips 2","tips 3"]}$close\n'
      'Isi 2-3 item. Angka tanpa satuan. Jangan mengosongkan blok ini.';

  static String stripForDisplay(String text) {
    final start = text.indexOf(open);
    if (start < 0) return text.trim();
    return text.substring(0, start).trim();
  }

  static MenuPlan? parse(String text) {
    final start = text.indexOf(open);
    final end = text.indexOf(close);
    if (start < 0 || end <= start) return null;
    final raw = text.substring(start + open.length, end).trim();
    try {
      final decoded = jsonDecode(raw);
      final Map<String, dynamic> obj;
      if (decoded is Map<String, dynamic>) {
        obj = decoded;
      } else if (decoded is List) {
        obj = {'items': decoded};
      } else {
        return null;
      }
      final rawItems = obj['items'];
      final items = <MenuItem>[];
      if (rawItems is List) {
        for (final it in rawItems.take(4)) {
          if (it is! Map) continue;
          final map = it.cast<String, dynamic>();
          final name = _str(map['name']);
          if (name.isEmpty) continue;
          items.add(MenuItem(
            name: name,
            type: _str(map['type']).isEmpty ? 'makanan' : _str(map['type']),
            costIdr: _int(map['cost_idr']),
            calories: _int(map['calories']),
            proteinG: _dbl(map['protein_g']),
            ingredients: _list(map['bahan']),
            steps: _list(map['langkah']),
            note: _str(map['catatan']),
          ));
        }
      }
      if (items.isEmpty) return null;
      return MenuPlan(
        items: items,
        shoppingTips: _list(obj['tips_belanja']),
        displayText: stripForDisplay(text),
      );
    } catch (_) {
      return null;
    }
  }

  static List<String> _list(Object? v) {
    if (v is List) {
      return v.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    }
    if (v is String && v.trim().isNotEmpty) {
      return v
          .split(RegExp(r'\n|;'))
          .map((e) => e.replaceFirst(RegExp(r'^\s*[-*•]\s*'), '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String _str(Object? v) => v == null ? '' : '$v'.trim();

  static int _int(Object? v) {
    if (v is num) return v.round();
    return int.tryParse('$v') ?? 0;
  }

  static double _dbl(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }
}
