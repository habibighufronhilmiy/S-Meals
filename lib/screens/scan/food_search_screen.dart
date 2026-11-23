import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/sona_store.dart';
import '../../domain/nutrition.dart';
import '../../models/meal_log.dart';
import '../../services/ai_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sona_components.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Layar pencarian makanan dari tabel master `foods` (server D1).
///
/// Memungkinkan user mencatat makanan tanpa foto — cukup ketik nama.
class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({
    super.key,
    required this.store,
    this.onSaved,
  });

  final SonaStore store;
  final VoidCallback? onSaved;

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];
  final Set<int> _adding = {};

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
          '${AiConfig.proxyBaseUrl}foods?q=${Uri.encodeQueryComponent(q)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw Exception('Server membalas ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['foods'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _results = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _add(Map<String, dynamic> food) async {
    final id = (food['id'] as num).toInt();
    setState(() => _adding.add(id));
    final meal = MealLog(
      id: 'f${DateTime.now().microsecondsSinceEpoch}',
      name: food['nama'] as String? ?? 'Makanan',
      calories: (food['kalori'] as num?)?.round() ?? 0,
      proteinG: (food['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (food['karbo_g'] as num?)?.toDouble() ?? 0,
      fatG: (food['lemak_g'] as num?)?.toDouble() ?? 0,
      sugarG: (food['gula_g'] as num?)?.toDouble() ?? 0,
      saltG: ((food['garam_mg'] as num?)?.toDouble() ?? 0) / 1000,
      score: MealScoring.score(
        calories: (food['kalori'] as num?)?.round() ?? 0,
        proteinG: (food['protein_g'] as num?)?.toDouble() ?? 0,
        sugarG: (food['gula_g'] as num?)?.toDouble() ?? 0,
        saltMg: (food['garam_mg'] as num?)?.toDouble() ?? 0,
      ),
      createdAt: DateTime.now(),
      priceIdr: (food['harga_idr'] as num?)?.round(),
    );
    await widget.store.addMeal(meal);
    if (!mounted) return;
    setState(() => _adding.remove(id));
    widget.onSaved?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${meal.name} ditambahkan ke catatan.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Cari Makanan'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(SonaSpacing.margin),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Ketik nama makanan (mis. nasi goreng)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: scheme.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SonaRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return SonaErrorView(
        message: _error!,
        onRetry: () => _search(_controller.text),
      );
    }
    if (_results.isEmpty) {
      return const SonaEmptyState(
        icon: Icons.search_off,
        title: 'Tidak ada makanan yang cocok',
        message: 'Coba kata kunci lain, atau pindai foto makanannya.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          SonaSpacing.margin, 0, SonaSpacing.margin, SonaSpacing.lg),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: SonaSpacing.sm),
      itemBuilder: (context, i) {
        final f = _results[i];
        final id = (f['id'] as num).toInt();
        final adding = _adding.contains(id);
        return SonaCard(
          padding: const EdgeInsets.all(SonaSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f['nama'] as String? ?? '-',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${f['kategori']} • ${f['porsi_standar']}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${f['kalori']} kkal • P ${f['protein_g']}g • '
                      'K ${f['karbo_g']}g • L ${f['lemak_g']}g',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SonaSpacing.sm),
              IconButton.filled(
                onPressed: adding ? null : () => _add(f),
                style: IconButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                icon: adding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
              ),
            ],
          ),
        );
      },
    );
  }
}
