import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/sona_store.dart';
import '../../domain/nutrition.dart';
import '../../models/meal_log.dart';
import '../../services/barcode_service.dart';
import '../../theme/app_theme.dart';

/// Layar pindai barcode produk kemasan, lalu simpan gizi ke catatan.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({
    super.key,
    required this.store,
    this.onSaved,
  });

  final SonaStore store;
  final VoidCallback? onSaved;

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _service = BarcodeService();
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );

  bool _busy = false;
  String _status = '';
  BarcodeProduct? _product;
  MealTime _waktu = MealTime.fromHour(DateTime.now().hour);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _product != null) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null || raw.isEmpty) return;

    setState(() {
      _busy = true;
      _status = 'Mencari produk $raw...';
    });
    await _controller.stop();

    try {
      final product = await _service.lookup(raw);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _product = product;
        _status = product == null
            ? 'Produk belum ada di database. Coba pindai label gizinya lewat tab Pindai.'
            : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _product = null;
        _status = 'Tidak bisa mencari produk. Pastikan internet tersambung lalu coba lagi.';
      });
      _controller.start();
    }
  }

  Future<void> _save() async {
    final p = _product;
    if (p == null) return;
    final log = MealScoring.toMealLog(
      p.toParsed(),
      waktuMakan: _waktu,
    );
    await widget.store.addMeal(log);
    if (!mounted) return;
    widget.onSaved?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${p.name} tersimpan ke catatan')),
    );
    Navigator.of(context).pop();
  }

  void _rescan() {
    setState(() {
      _product = null;
      _status = '';
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Pindai Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(SonaSpacing.lg),
                child: Text(
                  'Kamera tidak bisa dibuka: ${error.errorCode.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
          // Bingkai pandu
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: SonaColors.emerald, width: 3),
                borderRadius: BorderRadius.circular(SonaRadius.md),
              ),
            ),
          ),
          if (_busy)
            const Center(
              child: CircularProgressIndicator(color: SonaColors.emerald),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: SonaSpacing.lg),
              child: Text(
                'Arahkan kamera ke barcode produk',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ),
          ),
          if (_status.isNotEmpty && _product == null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(SonaSpacing.md),
                padding: const EdgeInsets.all(SonaSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(SonaRadius.md),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_status, textAlign: TextAlign.center),
                    const SizedBox(height: SonaSpacing.sm),
                    FilledButton(
                      onPressed: _rescan,
                      style: FilledButton.styleFrom(
                          backgroundColor: SonaColors.primary),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            ),
          if (_product != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _productSheet(_product!),
            ),
        ],
      ),
    );
  }

  Widget _productSheet(BarcodeProduct p) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(SonaSpacing.md),
      padding: const EdgeInsets.all(SonaSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SonaRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${p.calories} kkal/100g • ${p.proteinG.round()}g protein • '
            '${p.carbsG.round()}g karbo • ${p.fatG.round()}g lemak',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: SonaSpacing.sm),
          Text('Untuk waktu makan apa?',
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: SonaSpacing.sm,
            children: MealTime.values.map((t) {
              final on = _waktu == t;
              return ChoiceChip(
                label: Text(t.label),
                selected: on,
                onSelected: (_) => setState(() => _waktu = t),
                selectedColor: SonaColors.primary,
                labelStyle: TextStyle(
                    color: on ? SonaColors.onPrimary : SonaColors.onSurface),
                backgroundColor: SonaColors.surfaceContainerLowest,
              );
            }).toList(),
          ),
          const SizedBox(height: SonaSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _rescan,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SonaRadius.md),
                    ),
                  ),
                  child: const Text('Pindai lagi'),
                ),
              ),
              const SizedBox(width: SonaSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: SonaColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SonaRadius.md),
                    ),
                  ),
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
