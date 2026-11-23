import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/budget_recommender.dart';
import '../../models/meal_log.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sona_animations.dart';
import '../../widgets/sona_components.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.name,
    required this.summary,
    required this.recent,
    required this.streak,
    required this.calorieTarget,
    required this.budgetIdr,
    this.budgetPicks = const [],
    this.sisaBudgetIdr,
    this.onScan,
    this.onRecipes,
    this.onBudget,
    this.onHistory,
    this.onPickFood,
    this.onEditTarget,
    this.onOpenMeal,
  });

  final String name;
  final DailySummary summary;
  final List<MealLog> recent;
  final int streak;
  final int calorieTarget;
  final int budgetIdr;
  final List<FoodPick> budgetPicks;
  final int? sisaBudgetIdr;
  final VoidCallback? onScan;
  final VoidCallback? onRecipes;
  final VoidCallback? onBudget;
  final VoidCallback? onHistory;
  final ValueChanged<FoodPick>? onPickFood;
  final VoidCallback? onEditTarget;
  final ValueChanged<MealLog>? onOpenMeal;

  static String formatInt(int value) => NumberFormat.decimalPattern('id_ID').format(value);
  static String formatRupiah(int value) => 'Rp ${formatInt(value)}';

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('home-list'),
      padding: const EdgeInsets.fromLTRB(
          SonaSpacing.margin, SonaSpacing.md, SonaSpacing.margin, SonaSpacing.lg),
      children: [
        SonaEntrance(
          child: _HeroCard(name: name, streak: streak),
        ),
        const SizedBox(height: SonaSpacing.md),
        SonaEntrance(
          delay: const Duration(milliseconds: 70),
          child: _AchievementCard(
            summary: summary,
            target: calorieTarget,
            budget: budgetIdr,
            onEditTarget: onEditTarget,
          ),
        ),
        if (budgetPicks.isNotEmpty) ...[
          const SizedBox(height: SonaSpacing.md),
          SonaEntrance(
            delay: const Duration(milliseconds: 120),
            child: _BudgetPicksCard(
              picks: budgetPicks,
              sisaBudget: sisaBudgetIdr,
              onPick: onPickFood,
            ),
          ),
        ],
        const SizedBox(height: SonaSpacing.lg),
        SonaEntrance(
          delay: const Duration(milliseconds: 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aksi cepat', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: SonaSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.camera_alt,
                      label: 'Pindai',
                      color: SonaColors.emerald,
                      onTap: onScan,
                    ),
                  ),
                  const SizedBox(width: SonaSpacing.sm),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.restaurant,
                      label: 'Resep hemat',
                      color: SonaColors.amber,
                      onTap: onRecipes,
                    ),
                  ),
                  const SizedBox(width: SonaSpacing.sm),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.storefront,
                      label: 'Budget kos',
                      color: const Color(0xFF3FA97A),
                      onTap: onBudget,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: SonaSpacing.lg),
        SonaEntrance(
          delay: const Duration(milliseconds: 220),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Terakhir dipindai',
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text('Ketuk untuk melihat rinciannya',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              TextButton(
                onPressed: onHistory,
                child: Text('Lihat semua',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: SonaColors.primary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: SonaSpacing.sm),
        if (recent.isEmpty)
          SonaEntrance(
            delay: const Duration(milliseconds: 260),
            child: _EmptyRecent(onTap: onScan),
          )
        else
          ...recent.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: SonaSpacing.sm),
                child: SonaEntrance(
                  key: ValueKey('meal-${entry.value.id}'),
                  delay: Duration(milliseconds: 260 + entry.key * 60),
                  child: _MealRow(
                    meal: entry.value,
                    onTap: onOpenMeal == null ? null : () => onOpenMeal!(entry.value),
                  ),
                ),
              )),
        const SizedBox(height: SonaSpacing.lg),
        SonaEntrance(
          delay: const Duration(milliseconds: 320),
          child: Text(
            'Hasil ini perkiraan AI, bukan nasihat medis.',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.name, required this.streak});

  final String name;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final sapaan = name.isEmpty ? 'Halo, apa makanmu hari ini?' : 'Halo, $name';
    return Container(
      padding: const EdgeInsets.all(SonaSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SonaRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surfaceContainerHigh,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jaga gizi, jaga dompet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: SonaColors.primary,
                          fontWeight: FontWeight.w800,
                        )),
                const SizedBox(height: 4),
                Text(sapaan, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Catat makananmu hari ini biar gizi tetap seimbang dan budget kos aman.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: SonaSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(SonaRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 13, color: SonaColors.amberDeep),
                      const SizedBox(width: 4),
                      Text(
                        streak > 0
                            ? '$streak hari berturut-turut mencatat'
                            : 'Mulai catat makanmu hari ini',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: SonaColors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SonaSpacing.sm),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.restaurant,
                size: 28, color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.summary,
    required this.target,
    required this.budget,
    this.onEditTarget,
  });

  final DailySummary summary;
  final int target;
  final int budget;
  final VoidCallback? onEditTarget;

  @override
  Widget build(BuildContext context) {
    final consumed = summary.totalCalories;
    final fraction = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final spent = summary.totalSpentIdr;
    final budgetFraction = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

    return SonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Pencapaian Nutrisi',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              GestureDetector(
                onTap: onEditTarget,
                child: Text('Ubah target',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: SonaColors.primary,
                        )),
              ),
            ],
          ),
          const SizedBox(height: SonaSpacing.md),
          Row(
            children: [
              _CalorieRing(fraction: fraction, consumed: consumed),
              const SizedBox(width: SonaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      HomeScreen.formatInt(consumed),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: SonaColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text('dari ${HomeScreen.formatInt(target)} kkal',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: SonaSpacing.sm),
                    SonaProgressBar(fraction: fraction, color: SonaColors.emerald),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SonaSpacing.md),
          const _Divider(),
          const SizedBox(height: SonaSpacing.md),
          Text('Makronutrisi', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: SonaSpacing.sm),
          MacroBar(
            label: 'Protein',
            value: '${summary.totalProtein.round()} g',
            fraction: (summary.totalProtein / 60).clamp(0.0, 1.0),
            barColor: SonaColors.emerald,
          ),
          const SizedBox(height: SonaSpacing.sm),
          MacroBar(
            label: 'Karbohidrat',
            value: '${summary.totalCarbs.round()} g',
            fraction: (summary.totalCarbs / 250).clamp(0.0, 1.0),
            barColor: SonaColors.amber,
          ),
          const SizedBox(height: SonaSpacing.sm),
          MacroBar(
            label: 'Lemak',
            value: '${summary.totalFat.round()} g',
            fraction: (summary.totalFat / 65).clamp(0.0, 1.0),
            barColor: SonaColors.coral,
          ),
          const SizedBox(height: SonaSpacing.sm),
          MacroBar(
            label: 'Gula',
            value: '${summary.totalSugar.round()} g',
            fraction: (summary.totalSugar / 50).clamp(0.0, 1.0),
            barColor: SonaColors.pink,
          ),
          const SizedBox(height: SonaSpacing.md),
          const _Divider(),
          const SizedBox(height: SonaSpacing.md),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: SonaColors.amberTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.savings,
                    size: 18, color: SonaColors.amberDeep),
              ),
              const SizedBox(width: SonaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Budget makan',
                        style: Theme.of(context).textTheme.labelMedium),
                    Text(
                      'Terpakai ${HomeScreen.formatRupiah(spent)} dari ${HomeScreen.formatRupiah(budget)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SonaSpacing.sm),
          SonaProgressBar(fraction: budgetFraction, color: SonaColors.amber),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: SonaColors.outlineVariant.withValues(alpha: 0.4));
  }
}

class _CalorieRing extends StatelessWidget {
  const _CalorieRing({required this.fraction, required this.consumed});

  final double fraction;
  final int consumed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 10,
              backgroundColor: const Color(0xFFDCE9E3),
              valueColor: const AlwaysStoppedAnimation(SonaColors.emerald),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                HomeScreen.formatInt(consumed),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text('kkal', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SonaRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: SonaSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(SonaRadius.md),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: SonaSpacing.xs),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SonaCard(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: [
          Text('Belum ada yang dipindai hari ini.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: SonaSpacing.sm),
          GestureDetector(
            onTap: onTap,
            child: Text('Pindai makanan pertamamu',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: SonaColors.primary,
                    )),
          ),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, this.onTap});

  final MealLog meal;
  final VoidCallback? onTap;

  Color get _scoreColor => switch (meal.score) {
        MealScore.a => SonaColors.emerald,
        MealScore.bPlus => const Color(0xFF3FA97A),
        MealScore.b => SonaColors.amber,
        MealScore.c => SonaColors.coral,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SonaCard(
        child: Row(
          children: [
            if (meal.imageThumb != null && meal.imageThumb!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(SonaRadius.sm),
                child: Image.memory(
                  base64Decode(meal.imageThumb!),
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _scoreColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  meal.score.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _scoreColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
          const SizedBox(width: SonaSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${meal.calories} kkal . ${meal.proteinG.round()} g protein',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              size: 18, color: SonaColors.onSurfaceVariant),
        ],
        ),
      ),
    );
  }
}

/// Kartu rekomendasi menu yang pas dengan sisa budget hari ini.
class _BudgetPicksCard extends StatelessWidget {
  const _BudgetPicksCard({
    required this.picks,
    required this.sisaBudget,
    this.onPick,
  });

  final List<FoodPick> picks;
  final int? sisaBudget;
  final ValueChanged<FoodPick>? onPick;

  @override
  Widget build(BuildContext context) {
    final sisa = sisaBudget;
    return SonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings, size: 20, color: SonaColors.secondary),
              const SizedBox(width: SonaSpacing.xs),
              Expanded(
                child: Text('Pas buat sisa budget',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
              ),
              if (sisa != null)
                Text(
                  HomeScreen.formatRupiah(sisa),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: SonaColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sisa == null
                ? 'Atur budget harian untuk rekomendasi lebih pas.'
                : 'Masakan di bawah ini masih masuk sisa budgetmu hari ini.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SonaSpacing.sm),
          ...picks.map((p) => InkWell(
                borderRadius: BorderRadius.circular(SonaRadius.sm),
                onTap: onPick == null ? null : () => onPick!(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: SonaColors.amberTint,
                        ),
                        child: const Icon(Icons.restaurant,
                            size: 18, color: SonaColors.amberDeep),
                      ),
                      const SizedBox(width: SonaSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.nama,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium),
                            Text('${p.kalori} kkal . ${p.proteinG.round()} g protein',
                                style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                      Text(
                        HomeScreen.formatRupiah(p.hargaIdr),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: SonaColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: SonaSpacing.xs),
                      const Icon(Icons.add_circle_outline,
                          size: 20, color: SonaColors.primary),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
