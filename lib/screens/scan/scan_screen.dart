import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/sona_store.dart';
import '../../domain/nutrition.dart';
import '../../models/meal_log.dart';
import '../../services/ai_service.dart';
import '../../services/thumbnail_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sona_animations.dart';
import '../../widgets/sona_components.dart';
import '../../widgets/sona_page_route.dart';
import 'barcode_scan_screen.dart';
import 'food_search_screen.dart';
import 'scan_result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.store,
    required this.ai,
    this.onSaved,
    this.cameraRequest = 0,
  });

  final SonaStore store;
  final AiService ai;
  final VoidCallback? onSaved;

  /// Nonce; bertambah tiap user menekan tombol Scan. Nilai > 0 meminta
  /// kamera dibuka otomatis (baik saat mount maupun saat nonce berubah).
  final int cameraRequest;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();

  ScanMode _mode = ScanMode.food;
  File? _image;
  bool _busy = false;
  bool _starting = false;
  String _status = '';
  String? _error;
  int _handledRequest = 0;

  @override
  void initState() {
    super.initState();
    _handledRequest = widget.cameraRequest;
    if (widget.cameraRequest > 0) _openCameraOnce();
  }

  @override
  void didUpdateWidget(covariant ScanScreen old) {
    super.didUpdateWidget(old);
    if (widget.cameraRequest != _handledRequest) {
      _handledRequest = widget.cameraRequest;
      if (widget.cameraRequest > 0) _openCameraOnce();
    }
  }

  void _openCameraOnce() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_busy && !_starting) _start(ImageSource.camera);
    });
  }

  Future<void> _start(ImageSource source) async {
    if (_busy || _starting) return;
    _starting = true;
    File? image;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 82,
      );
      if (picked == null || !mounted) return;
      image = File(picked.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Gagal membuka kamera/galeri. Coba lagi ya.';
          _status = '';
        });
      }
      return;
    } finally {
      _starting = false;
    }
    if (!mounted) return;
    setState(() {
      _image = image;
      _busy = true;
      _error = null;
      _status = 'Sona sedang membaca fotonya...';
    });
    await _analyze(image);
  }

  Future<void> _analyze(File image) async {
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final thumb = ThumbnailService.toBase64Jpeg(bytes);
      final mime =
          image.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      final prompt = _mode == ScanMode.food
          ? 'Tolong analisis foto makanan ini. Sebutkan nama makanannya, lalu '
              'perkirakan kalori, protein, karbohidrat, lemak, gula, dan garamnya. '
              'Tutup dengan catatan singkat apakah pilihan ini sudah seimbang.'
          : 'Tolong baca label kemasan pada foto ini. Sebutkan nama produknya, '
              'lalu baca informasi nilai gizi per sajian: kalori, protein, '
              'karbohidrat, lemak, gula, dan garam. Jelaskan bagian yang perlu '
              'diwaspadai, lalu beri alternatif yang lebih sehat bila ada.';
      final fullPrompt = '$prompt\n\n${NutritionExtractor.instruction}';

      var answer = await _runVision(fullPrompt, base64Image, mime);
      var parsed = NutritionExtractor.parse(answer);

      // Model kadang lupa blok JSON. Coba sekali lagi dengan penekanan.
      if (parsed == null && mounted) {
        setState(() => _status = 'Merapikan angka gizinya...');
        answer = await _runVision(
          '$fullPrompt\n'
          'PENTING: balasan WAJIB diakhiri blok '
          '${NutritionExtractor.open}...${NutritionExtractor.close} berisi JSON '
          'valid sesuai skema. Jangan mengosongkannya.',
          base64Image,
          mime,
        );
        parsed = NutritionExtractor.parse(answer);
      }

      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
      });

      final rescan = await Navigator.of(context).push<bool>(
        SonaFadeSlideRoute(
          builder: (_) => ScanResultScreen(
            store: widget.store,
            answer: answer,
            mode: _mode,
            imagePath: image.path,
            thumb: thumb,
            parsed: parsed,
            initialTime: MealTime.fromHour(DateTime.now().hour),
            onSaved: widget.onSaved,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _image = null;
        _status = '';
        _error = null;
      });
      // Hanya buka kamera lagi jika user menekan "Pindai Ulang" (rescan == true).
      if (rescan == true) await _start(ImageSource.camera);
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
        _error = 'Koneksi AI gagal: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
        _error = friendlyError(e);
      });
    }
  }

  Future<String> _runVision(
      String prompt, String base64Image, String mime) async {
    return widget.ai.complete(
      prompt: prompt,
      mode: _mode == ScanMode.food ? AiMode.food : AiMode.label,
      imageBase64: base64Image,
      mimeType: mime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _busy
          ? KeyedSubtree(
              key: const ValueKey('scan-loading'),
              child: _loading(),
            )
          : KeyedSubtree(
              key: const ValueKey('scan-list'),
              child: _content(),
            ),
    );
  }

  Widget _content() {
    return ListView(
      key: const ValueKey('scan-list-scroll'),
      padding: const EdgeInsets.fromLTRB(
          SonaSpacing.margin, SonaSpacing.md, SonaSpacing.margin, SonaSpacing.lg),
      children: [
        SonaEntrance(
          delay: Duration.zero,
          child: _modeCards(),
        ),
        const SizedBox(height: SonaSpacing.lg),
        SonaEntrance(
          delay: const Duration(milliseconds: 80),
          child: _cameraButton(),
        ),
        const SizedBox(height: SonaSpacing.sm),
        SonaEntrance(
          delay: const Duration(milliseconds: 140),
          child: Row(
            children: [
              Expanded(
                child: _secondary(
                  icon: Icons.photo_library_outlined,
                  label: 'Galeri',
                  onTap: () => _start(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: SonaSpacing.sm),
              Expanded(
                child: _secondary(
                  icon: Icons.search,
                  label: 'Cari makanan',
                  onTap: () => Navigator.of(context).push(
                    SonaFadeSlideRoute(
                      builder: (_) => FoodSearchScreen(
                        store: widget.store,
                        onSaved: widget.onSaved,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SonaSpacing.sm),
              Expanded(
                child: _secondary(
                  icon: Icons.qr_code_scanner,
                  label: 'Barcode',
                  onTap: () => Navigator.of(context).push(
                    SonaFadeSlideRoute(
                      builder: (_) => BarcodeScanScreen(
                        store: widget.store,
                        onSaved: widget.onSaved,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: SonaSpacing.md),
          _errorCard(),
        ],
        const SizedBox(height: SonaSpacing.lg),
        SonaEntrance(
          delay: const Duration(milliseconds: 200),
          child: _tips(),
        ),
        const SizedBox(height: SonaSpacing.md),
        SonaEntrance(
          delay: const Duration(milliseconds: 240),
          child: Text(
            'Foto hanya dikirim saat kamu memindai. Hasil ini perkiraan AI, '
            'bukan nasihat medis.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }

  Widget _modeCards() {
    Widget card(ScanMode mode, IconData icon, String title, String subtitle) {
      final selected = _mode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _mode = mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(SonaSpacing.md),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(SonaRadius.md),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon,
                    size: 24,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: SonaSpacing.sm),
                Text(title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mau pindai apa?',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: SonaSpacing.sm),
        Row(
          children: [
            card(ScanMode.food, Icons.restaurant,
                'Piring Makanan', 'Hitung gizi dari foto'),
            const SizedBox(width: SonaSpacing.sm),
            card(ScanMode.label, Icons.local_offer_outlined,
                'Label Nutrisi', 'Baca kemasan'),
          ],
        ),
      ],
    );
  }

  Widget _cameraButton() {
    return GestureDetector(
      onTap: () => _start(ImageSource.camera),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SonaRadius.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3310B981),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              child: Icon(Icons.camera_alt,
                  size: 34, color: Theme.of(context).colorScheme.onPrimary),
            ),
            const SizedBox(height: SonaSpacing.md),
            Text('Buka Kamera',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 2),
            Text(
              _mode == ScanMode.food
                  ? 'Arahkan ke piring makanan'
                  : 'Arahkan ke tabel informasi gizi',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secondary({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SonaRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: SonaSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(SonaRadius.md),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 11,
                    )),
          ],
        ),
      ),
    );
  }

  Widget _loading() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(SonaSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(SonaRadius.lg),
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Image.file(_image!, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: SonaSpacing.lg),
            const CircularProgressIndicator(color: SonaColors.primary),
            const SizedBox(height: SonaSpacing.md),
            Text(
              _status.isEmpty ? 'Menganalisis foto...' : _status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Biasanya 5-15 detik. Jangan tutup aplikasi dulu ya.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard() {
    return SonaCard(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: SonaSpacing.sm),
          Expanded(
            child: Text(_error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    )),
          ),
          TextButton(
            onPressed: () => _start(ImageSource.camera),
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _tips() {
    return Container(
      padding: const EdgeInsets.all(SonaSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(SonaRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              size: 20, color: Theme.of(context).colorScheme.tertiary),
          const SizedBox(width: SonaSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tips foto yang jelas',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                const SizedBox(height: 2),
                Text(
                  'Gunakan cahaya cukup, dekatkan kamera, dan pastikan seluruh '
                  'piring atau tabel gizi masuk ke bingkai.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
