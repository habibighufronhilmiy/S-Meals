import 'package:flutter/material.dart';

import '../../domain/menu_plan.dart';
import '../../domain/nutrition.dart';
import '../../domain/text_format.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sona_components.dart';

class MenusScreen extends StatefulWidget {
  const MenusScreen({super.key, required this.ai});

  final AiService ai;

  @override
  State<MenusScreen> createState() => _MenusScreenState();
}

class _MenusScreenState extends State<MenusScreen> {
  final _ingredientController = TextEditingController();
  final List<String> _ingredients = ['Telur 2 butir', 'Tomat 1 buah', 'Kecap manis'];
  MenuPlan? _plan;
  List<String> _tips = const [];
  bool _busy = false;
  String? _error;
  int _budgetIndex = 1;
  int _toolIndex = 0;

  static const _budgets = ['< Rp 10.000', 'Rp 10.000 - 20.000', 'Bahan sisa kulkas'];
  static const _tools = [
    'Panci Listrik',
    'Kompor 1 Tungku',
    'Tanpa Masak',
  ];

  @override
  void dispose() {
    _ingredientController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final text = _ingredientController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _ingredients.add(text);
      _ingredientController.clear();
    });
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bahan =
          _ingredients.isEmpty ? 'bahan seadanya di kulkas' : _ingredients.join(', ');
      final prompt =
          'Racik 2-3 ide menu sehat dan murah untuk anak kos dari bahan berikut: '
          '$bahan. Budget: ${_budgets[_budgetIndex]}. Alat masak: ${_tools[_toolIndex]}.\n'
          'ATURAN PENTING:\n'
          '- Kalau bahan utamanya untuk minuman (teh, kopi, susu, buah, sirup, '
          'gula, es), hasilnya HARUS minuman. Jangan memaksakan jadi makanan berat.\n'
          '- Kalau bahan utamanya makanan (nasi, telur, mie, tahu, tempe, sayur, '
          'daging), hasilnya makanan. Jangan menambah bahan yang tidak disebut user.\n'
          '- Setiap menu wajib memakai bahan yang benar-benar disebut user. Sebutkan '
          'bahan tambahan hanya bila memang umum (air, garam, minyak).\n'
          '- Tulis langkah singkat 2-4 langkah, bukan paragraf panjang.\n'
          '- Jangan pakai markdown, tanda bintang, atau emoji.\n'
          '- Tips belanja harus spesifik untuk bahan yang diinput, bukan tips umum.\n'
          'Untuk setiap menu sebutkan nama, perkiraan biaya per porsi, kalori, '
          'protein, bahan, langkah, dan satu kalimat alasan cocok.\n\n'
          '${MenuPlanExtractor.instruction}';

      var answer = await widget.ai.complete(prompt: prompt, mode: AiMode.text);
      var plan = MenuPlanExtractor.parse(answer);

      if (plan == null) {
        answer = await widget.ai.complete(
          prompt: '$prompt\n\nPENTING: blok data mesin wajib ada dan valid.',
          mode: AiMode.text,
        );
        plan = MenuPlanExtractor.parse(answer);
      }

      final display = SonaText.cleanAi(MenuPlanExtractor.stripForDisplay(answer));
      final resolved = plan ??
          MenuPlan(items: const [], shoppingTips: const [], displayText: display);

      if (!mounted) return;
      setState(() {
        _busy = false;
        _plan = resolved;
        _tips = resolved.shoppingTips.isNotEmpty
            ? resolved.shoppingTips
            : _deriveTips(display);
      });
    } on AiException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Tidak bisa terhubung ke Sona. Silakan cek koneksi internet kamu lalu coba lagi.';
      });
    } catch (e) {
      if (!mounted) return;
      final s = e.toString().toLowerCase();
      if (s.contains('socket') ||
          s.contains('network') ||
          s.contains('timeout') ||
          s.contains('connection')) {
        setState(() {
          _busy = false;
          _error =
              'Tidak bisa terhubung ke Sona. Silakan cek koneksi internet kamu lalu coba lagi.';
        });
      } else {
        setState(() {
          _busy = false;
          _error =
              'Terjadi kendala saat meracik menu. Coba lagi dalam beberapa saat ya.';
        });
      }
    }
  }

  /// Cadangan bila AI lupa mengisi tips_belanja.
  List<String> _deriveTips(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final picked = lines
        .where((l) =>
            l.toLowerCase().contains('beli') ||
            l.toLowerCase().contains('hemat') ||
            l.toLowerCase().contains('pasar'))
        .take(3)
        .toList();
    if (picked.isNotEmpty) return picked;
    return [SonaText.firstSentences(text, maxSentences: 2)]
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SonaSpacing.margin, SonaSpacing.md, SonaSpacing.margin, SonaSpacing.lg),
      children: [
        _header(),
        const SizedBox(height: SonaSpacing.md),
        _toolChips(),
        const SizedBox(height: SonaSpacing.sm),
        _budgetChips(),
        const SizedBox(height: SonaSpacing.lg),
        _generatorCard(),
        const SizedBox(height: SonaSpacing.lg),
        if (_showResults) _resultsSection(),
        if (_tips.isNotEmpty) ...[
          const SizedBox(height: SonaSpacing.md),
          _tipBanner(),
        ],
      ],
    );
  }

  bool get _showResults => _busy || _error != null || _plan != null;

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SonaPill(
          text: 'DOMPET AMAN, PERUT KENYANG',
          background: SonaColors.amberTint,
          foreground: SonaColors.amberDeep,
        ),
        const SizedBox(height: SonaSpacing.sm),
        Text('Masak Praktis Anak Kos',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Masukkan bahan yang ada — Sona mendeteksi sendiri apakah itu untuk '
          'makanan atau minuman.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _toolChips() {
    return _chipRow(
      icon: Icons.kitchen_outlined,
      label: 'Alat',
      options: _tools,
      selected: _toolIndex,
      onSelect: (i) => setState(() => _toolIndex = i),
      activeColor: SonaColors.primary,
      activeText: SonaColors.onPrimary,
    );
  }

  Widget _budgetChips() {
    return _chipRow(
      icon: Icons.payments_outlined,
      label: 'Budget',
      options: _budgets,
      selected: _budgetIndex,
      onSelect: (i) => setState(() => _budgetIndex = i),
      activeColor: SonaColors.secondaryContainer,
      activeText: SonaColors.onSecondaryContainer,
    );
  }

  Widget _chipRow({
    required IconData icon,
    required String label,
    required List<String> options,
    required int selected,
    required ValueChanged<int> onSelect,
    required Color activeColor,
    required Color activeText,
  }) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Center(
            child: Row(
              children: [
                Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
              ],
            ),
          ),
          const SizedBox(width: SonaSpacing.sm),
          ...List.generate(options.length, (i) {
            final active = selected == i;
            return Padding(
              padding: const EdgeInsets.only(right: SonaSpacing.sm),
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? activeColor
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(SonaRadius.full),
                  ),
                  child: Text(
                    options[i],
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: active
                              ? activeText
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _generatorCard() {
    return Container(
      padding: const EdgeInsets.all(SonaSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SonaRadius.md),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerHigh,
            Theme.of(context).colorScheme.surfaceContainer,
            Theme.of(context).colorScheme.surfaceContainerLow,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(SonaRadius.sm),
                ),
                child: Icon(Icons.auto_fix_high,
                    size: 22, color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: SonaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Generator Bahan Sisa',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Ketik bahan nganggur di kosanmu!',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SonaPill(
                text: 'AI',
                background: SonaColors.emeraldTint,
                foreground: SonaColors.primary,
              ),
            ],
          ),
          const SizedBox(height: SonaSpacing.md),
          Container(
            padding: const EdgeInsets.all(SonaSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(SonaRadius.md),
            ),
            child: Column(
              children: [
                if (_ingredients.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _ingredients
                        .map((ing) => Chip(
                              label: Text(ing),
                              labelStyle: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.6),
                              deleteIcon: Icon(Icons.close,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer),
                              onDeleted: () =>
                                  setState(() => _ingredients.remove(ing)),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide.none,
                            ))
                        .toList(),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          borderRadius:
                              BorderRadius.circular(SonaRadius.sm),
                        ),
                        child: TextField(
                          controller: _ingredientController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addIngredient(),
                          decoration: InputDecoration(
                            hintText: 'Tambah bahan (+ cabai, nasi dingin...)',
                            hintStyle: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    const SizedBox(width: SonaSpacing.xs),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: _addIngredient,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.add_circle,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SonaSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _generate,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: SonaColors.onPrimary),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_busy ? 'Sona meracik...' : 'Racik Menu'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rekomendasi Menu Sona',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: SonaSpacing.sm),
        if (_error != null)
          SonaCard(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    size: 18, color: Theme.of(context).colorScheme.onErrorContainer),
                const SizedBox(width: SonaSpacing.sm),
                Expanded(
                  child: Text(_error!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer)),
                ),
              ],
            ),
          )
        else if (_busy)
          SonaCard(
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: SonaSpacing.sm),
                Expanded(
                  child: Text('Menyusun menu dari bahanmu...',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          )
        else if (_plan != null) ...[
          if (_plan!.items.isEmpty)
            SonaCard(
              child: Text(_plan!.displayText,
                  style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            ..._plan!.items.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: SonaSpacing.md),
                  child: _recipeCard(r),
                )),
        ],
      ],
    );
  }

  Widget _recipeCard(MenuItem r) {
    return SonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.name,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              SonaPill(
                text: r.isDrink ? 'Minuman' : 'Makanan',
                background: r.isDrink ? SonaColors.skyTint : SonaColors.emeraldTint,
                foreground: r.isDrink ? SonaColors.skyDeep : SonaColors.primary,
              ),
            ],
          ),
          const SizedBox(height: SonaSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(vertical: SonaSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(SonaRadius.md),
            ),
            child: Row(
              children: [
                _stat('Biaya', r.costIdr > 0 ? 'Rp ${r.costIdr}' : '—',
                    SonaColors.primary),
                _stat('Kalori', r.calories > 0 ? '${r.calories}' : '—',
                    SonaColors.onSurface),
                _stat('Protein',
                    r.proteinG > 0 ? '${MealScoring.formatGrams(r.proteinG)}g' : '—',
                    SonaColors.secondary),
              ],
            ),
          ),
          if (r.ingredients.isNotEmpty) ...[
            const SizedBox(height: SonaSpacing.sm),
            Text('Bahan', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            Text('• ${r.ingredients.join('\n• ')}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (r.steps.isNotEmpty) ...[
            const SizedBox(height: SonaSpacing.sm),
            Text('Cara membuat', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            for (var i = 0; i < r.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('${i + 1}. ${r.steps[i]}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
          if (r.note.isNotEmpty) ...[
            const SizedBox(height: SonaSpacing.sm),
            Text(r.note, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: SonaColors.onSurfaceVariant,
                  )),
          const SizedBox(height: 2),
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  )),
        ],
      ),
    );
  }

  Widget _tipBanner() {
    return Container(
      padding: const EdgeInsets.all(SonaSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(SonaRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_wallet,
                size: 24, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: SonaSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tips Belanja Anak Kos',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                for (final tip in _tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• $tip',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
