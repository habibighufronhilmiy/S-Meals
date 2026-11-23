import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/sona_store.dart';
import '../../domain/nutrition.dart';
import '../../models/meal_log.dart';
import '../../services/thumbnail_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sona_components.dart';
import '../../widgets/speak_button.dart';

/// Rincian satu catatan makan: foto, ringkasan AI, dan tabel gizi.
class MealDetailScreen extends StatefulWidget {
  const MealDetailScreen({
    super.key,
    required this.store,
    required this.meal,
    this.onChanged,
  });

  final SonaStore store;
  final MealLog meal;
  final VoidCallback? onChanged;

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  late MealTime _time;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _time = widget.meal.waktuMakan;
  }

  Color get _scoreColor => switch (widget.meal.score) {
        MealScore.a => SonaColors.emerald,
        MealScore.bPlus => const Color(0xFF3FA97A),
        MealScore.b => SonaColors.amber,
        MealScore.c => SonaColors.coral,
      };

  String _rupiah(int v) =>
      'Rp ${NumberFormat.decimalPattern('id_ID').format(v)}';

  Future<void> _setTime(MealTime t) async {
    await widget.store.setMealTime(widget.meal.id, t);
    if (!mounted) return;
    setState(() => _time = t);
    widget.onChanged?.call();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus catatan?'),
        content: Text('${widget.meal.name} akan dihapus dari catatan harian.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: SonaColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.store.removeMeal(widget.meal.id);
    if (!mounted) return;
    _deleted = true;
    widget.onChanged?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    if (_deleted) return const SizedBox.shrink();
    final date = DateFormat('EEEE, d MMMM yyyy • HH:mm', 'id_ID')
        .format(meal.createdAt);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Detail Catatan'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Hapus',
            onPressed: _delete,
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            SonaSpacing.margin, SonaSpacing.sm, SonaSpacing.margin, SonaSpacing.lg),
        children: [
          _photo(meal),
          const SizedBox(height: SonaSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meal.name,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text(date, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: SonaSpacing.sm),
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _scoreColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Text(meal.score.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _scoreColor,
                          fontWeight: FontWeight.w800,
                        )),
              ),
            ],
          ),
          if (meal.priceIdr != null && meal.priceIdr! > 0) ...[
            const SizedBox(height: SonaSpacing.xs),
            Row(
              children: [
                Icon(Icons.payments_outlined,
                    size: 16, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 4),
                Text(_rupiah(meal.priceIdr!),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w700,
                        )),
              ],
            ),
          ],
          const SizedBox(height: SonaSpacing.md),
          _nutritionTable(meal),
          const SizedBox(height: SonaSpacing.md),
          _summaryCard(meal),
          const SizedBox(height: SonaSpacing.md),
          _timeCard(),
          const SizedBox(height: SonaSpacing.lg),
          Text(
            'Perkiraan AI, bukan nasihat medis.',
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _photo(MealLog meal) {
    final bytes = ThumbnailService.fromBase64(meal.imageThumb);
    Widget image;
    if (bytes != null) {
      image = Image.memory(bytes, fit: BoxFit.cover);
    } else if (meal.imagePath != null) {
      image = Image.file(
        File(meal.imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _photoPlaceholder(),
      );
    } else {
      return _photoPlaceholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(SonaRadius.md),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: image,
      ),
    );
  }

  Widget _photoPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.primaryContainer
            : SonaColors.emeraldTint,
        borderRadius: BorderRadius.circular(SonaRadius.md),
      ),
      child: Center(
        child: Icon(Icons.restaurant_menu,
            size: 52,
            color: isDark
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : SonaColors.primary),
      ),
    );
  }

  Widget _nutritionTable(MealLog meal) {
    final rows = [
      ('Energi', '${meal.calories} kkal'),
      ('Protein', '${MealScoring.formatGrams(meal.proteinG)} g'),
      ('Karbohidrat', '${MealScoring.formatGrams(meal.carbsG)} g'),
      ('Lemak', '${MealScoring.formatGrams(meal.fatG)} g'),
      ('Gula', '${MealScoring.formatGrams(meal.sugarG)} g'),
      ('Garam', '${(meal.saltG * 1000).round()} mg'),
    ];
    return SonaCard(
      padding: const EdgeInsets.all(SonaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tabel Gizi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SonaSpacing.sm),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.4),
              1: FlexColumnWidth(1),
            },
            children: [
              for (var i = 0; i < rows.length; i++)
                TableRow(
                  decoration: BoxDecoration(
                    color: i.isEven
                        ? Theme.of(context).colorScheme.surfaceContainerLow
                        : Colors.transparent,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: SonaSpacing.sm, vertical: 8),
                      child: Text(rows[i].$1,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: SonaSpacing.sm, vertical: 8),
                      child: Text(
                        rows[i].$2,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(MealLog meal) {
    final summary = (meal.summary ?? '').trim();
    if (summary.isEmpty) return const SizedBox.shrink();
    return SonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Catatan Sona',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              SpeakButton(text: summary, compact: true),
            ],
          ),
          const SizedBox(height: SonaSpacing.sm),
          Text(summary, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _timeCard() {
    return SonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Waktu makan',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SonaSpacing.sm),
          Wrap(
            spacing: SonaSpacing.sm,
            runSpacing: SonaSpacing.xs,
            children: MealTime.values.map((t) {
              final on = _time == t;
              return ChoiceChip(
                label: Text(t.label),
                selected: on,
                onSelected: (_) => _setTime(t),
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: on
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerLowest,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
