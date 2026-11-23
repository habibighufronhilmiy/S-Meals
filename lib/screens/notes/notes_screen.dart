import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/sona_store.dart';
import '../../domain/nutrition.dart';
import '../../models/meal_log.dart';
import '../../services/thumbnail_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sona_components.dart';
import '../../widgets/sona_page_route.dart';
import '../settings/reminder_screen.dart';
import 'meal_detail_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    required this.store,
    this.onChanged,
  });

  final SonaStore store;
  final VoidCallback? onChanged;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late DateTime _day;
  late List<MealLog> _meals;
  late DailySummary _summary;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _reload();
    _refreshFromServer();
  }

  Future<void> _refreshFromServer() async {
    await widget.store.refreshFromServer();
    if (mounted) setState(_reload);
  }

  void _reload() {
    _meals = widget.store.mealsOn(_day);
    _summary = widget.store.summaryOn(_day);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year &&
        _day.month == now.month &&
        _day.day == now.day;
  }

  void _shiftDay(int delta) {
    setState(() {
      _day = DateTime(_day.year, _day.month, _day.day + delta);
      _reload();
    });
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() {
        _day = DateTime(picked.year, picked.month, picked.day);
        _reload();
      });
    }
  }

  Future<void> _delete(MealLog meal) async {
    await widget.store.removeMeal(meal.id);
    setState(_reload);
    widget.onChanged?.call();
  }

  Future<void> _editBudget() async {
    final controller = TextEditingController(
      text: widget.store.dailyBudgetIdr > 0
          ? widget.store.dailyBudgetIdr.toString()
          : '',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Budget makan harian'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: 'Rp ',
            hintText: 'misal 30000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await widget.store.setDailyBudgetIdr(result);
      setState(() {});
      widget.onChanged?.call();
    }
  }

  String _rupiah(int v) => 'Rp ${NumberFormat.decimalPattern('id_ID').format(v)}';

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshFromServer,
      color: SonaColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SonaSpacing.margin, SonaSpacing.md, SonaSpacing.margin, SonaSpacing.lg),
        children: [
          _syncBadge(),
          const SizedBox(height: SonaSpacing.sm),
          _daySelector(),
        const SizedBox(height: SonaSpacing.md),
        _summaryCard(),
        const SizedBox(height: SonaSpacing.md),
        if (_isToday) ...[
          _waterCard(),
          const SizedBox(height: SonaSpacing.md),
        ],
        _budgetCard(),
        const SizedBox(height: SonaSpacing.md),
        _trendCard(),
        const SizedBox(height: SonaSpacing.lg),
        Text('Catatan Harian',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: SonaSpacing.sm),
        if (_meals.isEmpty)
          _empty()
        else
          ..._groupedTiles(),
      ],
      ),
    );
  }

  /// Badge status sinkron: semua tersinkron / ada yang belum / offline.
  Widget _syncBadge() {
    final auth = widget.store;
    final pending = auth.pendingSyncCount;
    final logged = widget.store.isAuthAttached;
    if (!logged) return const SizedBox.shrink();

    final bool ok = auth.lastSyncOk ?? true;
    final IconData icon;
    final Color color;
    final String text;
    if (!ok) {
      icon = Icons.cloud_off;
      color = SonaColors.error;
      text = pending > 0
          ? 'Offline • $pending catatan menunggu sinkron'
          : 'Offline • memakai data lokal';
    } else if (pending > 0) {
      icon = Icons.cloud_upload_outlined;
      color = SonaColors.amberDeep;
      text = '$pending catatan belum tersinkron';
    } else {
      icon = Icons.cloud_done;
      color = SonaColors.primary;
      text = 'Tersinkron ke cloud';
    }
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _daySelector() {
    final label = _isToday
        ? 'Hari ini, ${DateFormat('d MMM yyyy', 'id_ID').format(_day)}'
        : DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_day);
    return Row(
      children: [
        IconButton(
          onPressed: () => _shiftDay(-1),
          icon: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _pickDay,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: SonaSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(SonaRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 15, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => _shiftDay(1),
          icon: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  List<Widget> _groupedTiles() {
    final out = <Widget>[];
    for (final t in MealTime.values) {
      final items = _meals.where((m) => m.waktuMakan == t).toList();
      if (items.isEmpty) continue;
      out.add(Padding(
        padding: const EdgeInsets.only(
            top: SonaSpacing.sm, bottom: SonaSpacing.xs),
        child: Row(
          children: [
            Text(t.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: SonaColors.primary,
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(width: 6),
            Text('• ${items.fold<int>(0, (s, m) => s + m.calories)} kkal',
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ));
      out.addAll(items.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: SonaSpacing.sm),
            child: _mealTile(m),
          )));
    }
    // Catatan tanpa waktu terkelompok (fallback).
    return out;
  }

  Widget _summaryCard() {
    return SonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isToday ? 'Ringkasan Hari Ini' : 'Ringkasan Hari Itu',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SonaSpacing.md),
          Row(
            children: [
              _bigStat('${_summary.totalCalories}', 'kkal', SonaColors.primary),
              _bigStat(MealScoring.formatGrams(_summary.totalProtein), 'protein',
                  SonaColors.emerald),
              _bigStat(MealScoring.formatGrams(_summary.totalCarbs), 'karbo',
                  SonaColors.secondary),
              _bigStat(MealScoring.formatGrams(_summary.totalFat), 'lemak',
                  SonaColors.amberDeep),
            ],
          ),
          const SizedBox(height: SonaSpacing.sm),
          Row(
            children: [
              _bigStat(MealScoring.formatGrams(_summary.totalSugar), 'gula',
                  SonaColors.pink),
              _bigStat('${_summary.totalSalt.round()}', 'garam mg',
                  SonaColors.amberDeep),
              _bigStat(MealScoring.formatGrams(_summary.totalCarbs * 0.08),
                  'serat', SonaColors.emerald),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bigStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  )),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _waterCard() {
    return SonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: SonaColors.skyTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.water_drop,
                    size: 18, color: SonaColors.skyDeep),
              ),
              const SizedBox(width: SonaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pengingat Minum',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Aktifkan pengingat agar Sona mengingatkanmu minum.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SonaSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  SonaFadeSlideRoute(builder: (_) => ReminderScreen(store: widget.store)),
                );
              },
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Atur pengingat minum'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendCard() {
    final days = widget.store.recentDays(7);
    final maxCal = days
        .map((d) => d.totalCalories)
        .fold<int>(1, (a, b) => b > a ? b : a);
    final target = widget.store.calorieTarget;
    final labels = List.generate(7, (i) {
      final now = DateTime.now();
      final d = DateTime(now.year, now.month, now.day - (6 - i));
      return DateFormat('E', 'id_ID').format(d).substring(0, 2);
    });

    return SonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Tren Kalori 7 Hari',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text('target $target',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: SonaSpacing.md),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final cal = days[i].totalCalories;
                final h = maxCal > 0 ? (cal / maxCal) : 0.0;
                final over = target > 0 && cal > target;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${cal > 0 ? cal : ''}',
                          style: const TextStyle(fontSize: 9)),
                      const SizedBox(height: 2),
                      Container(
                        height: (h * 72).clamp(2.0, 72.0),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: over ? SonaColors.error : SonaColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(labels[i],
                          style: const TextStyle(fontSize: 9)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetCard() {
    final budget = widget.store.dailyBudgetIdr;
    final spent = _summary.totalSpentIdr;
    final fraction = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final remaining = budget - spent;

    return SonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                child: Text('Budget Makan Harian',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              GestureDetector(
                onTap: _editBudget,
                child: Text('Atur',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: SonaColors.primary,
                        )),
              ),
            ],
          ),
          const SizedBox(height: SonaSpacing.md),
          if (budget <= 0)
            Text('Belum diatur. Ketuk "Atur" untuk menetapkan budget harianmu.',
                style: Theme.of(context).textTheme.bodySmall)
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_rupiah(spent),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: SonaColors.primary,
                          fontWeight: FontWeight.w800,
                        )),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('dari ${_rupiah(budget)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                const Spacer(),
                Text(
                  remaining >= 0 ? 'Sisa ${_rupiah(remaining)}' : 'Lebih ${_rupiah(-remaining)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: remaining >= 0
                            ? SonaColors.primary
                            : SonaColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: SonaSpacing.sm),
            SonaProgressBar(
              fraction: fraction,
              color: remaining >= 0 ? SonaColors.amber : SonaColors.error,
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty() {
    return SonaEmptyState(
      icon: _isToday ? Icons.restaurant_menu : Icons.event_busy,
      title: _isToday ? 'Belum ada catatan hari ini' : 'Tidak ada catatan',
      message: _isToday
          ? 'Pindai foto makanan atau cari dari daftar untuk mulai mencatat.'
          : 'Belum ada makanan yang dicatat pada tanggal ini.',
    );
  }

  Widget _mealThumb(MealLog meal) {
    final bytes = ThumbnailService.fromBase64(meal.imageThumb);
    Widget img;
    if (bytes != null) {
      img = Image.memory(bytes, fit: BoxFit.cover);
    } else if (meal.imagePath != null) {
      img = Image.file(
        File(meal.imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.restaurant, color: SonaColors.primary),
      );
    } else {
      img = const Icon(Icons.restaurant, color: SonaColors.primary);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(SonaRadius.sm),
      child: Container(
        width: 44,
        height: 44,
        color: SonaColors.emeraldTint,
        child: img,
      ),
    );
  }

  Future<void> _openDetail(MealLog meal) async {
    await Navigator.of(context).push(
      SonaFadeSlideRoute(
        builder: (_) => MealDetailScreen(
          store: widget.store,
          meal: meal,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  Widget _mealTile(MealLog meal) {
    final scoreColor = switch (meal.score) {
      MealScore.a => SonaColors.emerald,
      MealScore.bPlus => const Color(0xFF3FA97A),
      MealScore.b => SonaColors.amber,
      MealScore.c => SonaColors.coral,
    };
    final time = DateFormat('HH:mm', 'id_ID').format(meal.createdAt);

    return Dismissible(
      key: ValueKey(meal.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(meal),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: SonaSpacing.md),
        decoration: BoxDecoration(
          color: SonaColors.error,
          borderRadius: BorderRadius.circular(SonaRadius.md),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => _openDetail(meal),
        child: SonaCard(
          child: Row(
            children: [
              if (meal.imageThumb != null || meal.imagePath != null) ...[
              _mealThumb(meal),
              const SizedBox(width: SonaSpacing.sm),
            ],
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(meal.score.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.w800,
                      )),
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
                    '$time • ${meal.calories} kkal • ${meal.proteinG.round()} g protein',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (meal.priceIdr != null)
                    Text(_rupiah(meal.priceIdr!),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: SonaColors.secondary,
                              fontWeight: FontWeight.w700,
                            )),
                ],
              ),
            ),
            PopupMenuButton<MealTime>(
              icon: const Icon(Icons.more_vert,
                  size: 18, color: SonaColors.onSurfaceVariant),
              onSelected: (t) async {
                await widget.store.setMealTime(meal.id, t);
                setState(_reload);
                widget.onChanged?.call();
              },
              itemBuilder: (ctx) => MealTime.values
                  .map((t) => PopupMenuItem(
                        value: t,
                        child: Text('Pindah ke ${t.label}'),
                      ))
                  .toList(),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
