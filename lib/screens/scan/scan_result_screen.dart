import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/sona_store.dart';
import '../../domain/nutrition.dart';
import '../../domain/text_format.dart';
import '../../models/meal_log.dart';
import '../../services/thumbnail_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sona_components.dart';
import '../../widgets/speak_button.dart';

enum ScanMode { food, label }

/// Halaman jawaban setelah foto dianalisis.
///
/// User bisa membaca rincian gizi, mendengarkan jawaban, menyimpan ke catatan,
/// atau memindai ulang.
class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({
    super.key,
    required this.store,
    required this.answer,
    required this.mode,
    this.imagePath,
    this.thumb,
    this.parsed,
    this.initialTime,
    this.onSaved,
  });

  final SonaStore store;
  final String answer;
  final ScanMode mode;
  final String? imagePath;
  final String? thumb;
  final ParsedNutrition? parsed;
  final MealTime? initialTime;
  final VoidCallback? onSaved;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  late MealTime _time;
  bool _saved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime ?? MealTime.fromHour(DateTime.now().hour);
  }

  String get _display =>
      SonaText.cleanAi(NutritionExtractor.stripForDisplay(widget.answer));

  Future<void> _save() async {
    final parsed = widget.parsed;
    if (parsed == null || _saving) return;
    setState(() => _saving = true);
    final log = MealScoring.toMealLog(
      parsed,
      imagePath: widget.imagePath,
      imageThumb: widget.thumb,
      waktuMakan: _time,
    );
    await widget.store.addMeal(log);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = true;
    });
    widget.onSaved?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tersimpan ke Catatan Harian')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parsed;
    final isLabel = widget.mode == ScanMode.label;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(isLabel ? 'Hasil Label Nutrisi' : 'Hasil Pindai'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            SonaSpacing.margin, SonaSpacing.sm, SonaSpacing.margin, SonaSpacing.lg),
        children: [
          _photo(),
          const SizedBox(height: SonaSpacing.md),
          if (p == null)
            _unreadableCard()
          else ...[
            _scoreCard(p, isLabel),
            const SizedBox(height: SonaSpacing.md),
            _nutrientCard(p),
            if (_display.isNotEmpty) ...[
              const SizedBox(height: SonaSpacing.md),
              _answerCard(),
            ],
            const SizedBox(height: SonaSpacing.md),
            _mealTimeCard(),
            const SizedBox(height: SonaSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saved || _saving ? null : _save,
                icon: Icon(_saved ? Icons.check_circle : Icons.bookmark_add),
                label: Text(_saved
                    ? 'Tersimpan di Catatan Harian'
                    : 'Simpan ke Catatan Harian'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _saved ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: SonaSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Pindai Ulang'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SonaRadius.full),
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: SonaSpacing.sm),
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Selesai'),
                ),
              ),
            ],
          ),
          const SizedBox(height: SonaSpacing.sm),
          Text(
            'Hasil ini perkiraan AI, bukan nasihat medis.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _photo() {
    final bytes = ThumbnailService.fromBase64(widget.thumb);
    Widget? image;
    if (bytes != null) {
      image = Image.memory(bytes, fit: BoxFit.cover);
    } else if (widget.imagePath != null) {
      image = Image.file(
        File(widget.imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _photoPlaceholder(),
      );
    }
    if (image == null) return _photoPlaceholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(SonaRadius.md),
      child: SizedBox(height: 200, width: double.infinity, child: image),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(SonaRadius.md),
      ),
      child: Center(
        child: Icon(Icons.restaurant_menu,
            size: 48, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _scoreCard(ParsedNutrition p, bool isLabel) {
    final score = MealScoring.score(
      calories: p.calories,
      proteinG: p.proteinG,
      sugarG: p.sugarG,
      saltMg: p.saltMg,
    );
    return SonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(score.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      )),
              ),
              const SizedBox(width: SonaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text(
                      isLabel
                          ? 'Perkiraan per sajian'
                          : (p.priceIdr != null
                              ? 'Rp ${p.priceIdr} / porsi'
                              : 'Perkiraan gizi AI'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SpeakButton(text: _display, compact: true),
            ],
          ),
          const SizedBox(height: SonaSpacing.md),
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  size: 20, color: SonaColors.primary),
              const SizedBox(width: 6),
              Text('Total Energi',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('${p.calories}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: SonaColors.primary,
                        fontWeight: FontWeight.w800,
                      )),
              const SizedBox(width: 2),
              Text('kkal', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          if (isLabel) ...[
            const SizedBox(height: SonaSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SonaSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(SonaRadius.sm),
              ),
              child: Text(
                'Angka di atas mengikuti takaran sajian pada kemasan. Cek lagi '
                'jumlah sajian yang kamu makan ya.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _nutrientCard(ParsedNutrition p) {
    final tiles = [
      ('Protein', '${MealScoring.formatGrams(p.proteinG)} g', SonaColors.emerald),
      ('Karbohidrat', '${MealScoring.formatGrams(p.carbsG)} g', SonaColors.amber),
      ('Lemak', '${MealScoring.formatGrams(p.fatG)} g', SonaColors.coral),
      ('Gula', '${MealScoring.formatGrams(p.sugarG)} g', SonaColors.pink),
      ('Garam', '${p.saltMg.round()} mg', SonaColors.secondary),
      ('Kalori', '${p.calories} kkal', SonaColors.primary),
    ];
    return SonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rincian Gizi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SonaSpacing.sm),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1),
            },
            children: [
              for (var i = 0; i < tiles.length; i++)
                TableRow(
                  decoration: BoxDecoration(
                    color: i.isEven
                        ? Theme.of(context).colorScheme.surfaceContainerHigh
                        : Colors.transparent,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: SonaSpacing.sm, vertical: 8),
                      child: Text(tiles[i].$1,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: SonaSpacing.sm, vertical: 8),
                      child: Text(
                        tiles[i].$2,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: tiles[i].$3,
                              fontWeight: FontWeight.w800,
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

  Widget _answerCard() {
    return SonaCard(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
              ),
              SpeakButton(text: _display, compact: true),
            ],
          ),
          const SizedBox(height: SonaSpacing.sm),
          Text(_display, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _unreadableCard() {
    return SonaCard(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.onErrorContainer),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Angka gizi belum terbaca',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        )),
              ),
            ],
          ),
          const SizedBox(height: SonaSpacing.sm),
          Text(
            _display.isEmpty
                ? 'Sona belum bisa membaca gizinya. Coba foto ulang dengan '
                    'pencahayaan lebih terang dan objek yang lebih dekat.'
                : _display,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
          ),
          if (_display.isNotEmpty) ...[
            const SizedBox(height: SonaSpacing.sm),
            SpeakButton(text: _display),
          ],
        ],
      ),
    );
  }

  Widget _mealTimeCard() {
    return SonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Waktu makan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SonaSpacing.sm),
          Wrap(
            spacing: SonaSpacing.sm,
            runSpacing: SonaSpacing.xs,
            children: MealTime.values.map((t) {
              final on = _time == t;
              return ChoiceChip(
                label: Text(t.label),
                selected: on,
                onSelected: (_) => setState(() => _time = t),
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: on
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
