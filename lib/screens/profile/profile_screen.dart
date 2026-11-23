import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/nutrition_calculator.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sona_components.dart';

/// Layar profil: tinggi/berat/umur/aktivitas/tujuan + target kalori otomatis.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.auth,
    required this.onSaved,
    required this.onLogout,
  });

  final AuthService auth;
  final ValueChanged<SonaUser> onSaved;
  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _tinggi = TextEditingController();
  final _berat = TextEditingController();
  final _umur = TextEditingController();
  final _budget = TextEditingController();

  String _gender = 'pria';
  String _aktivitas = 'ringan';
  String _tujuan = 'jaga';
  bool _saving = false;
  String? _error;
  int? _targetPreview;
  int? _usageToday;

  @override
  void initState() {
    super.initState();
    final u = widget.auth.user;
    if (u != null) {
      _tinggi.text = u.tinggiCm?.toString() ?? '';
      _berat.text = u.beratKg?.toString() ?? '';
      _umur.text = u.umur?.toString() ?? '';
      _budget.text = u.targetBudgetIdr.toString();
      _gender = u.jenisKelamin ?? 'pria';
      _aktivitas = u.aktivitas ?? 'ringan';
      _tujuan = u.tujuan ?? 'jaga';
    }
    _recompute();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    final n = await widget.auth.fetchUsageToday();
    if (mounted) setState(() => _usageToday = n);
  }

  @override
  void dispose() {
    _tinggi.dispose();
    _berat.dispose();
    _umur.dispose();
    _budget.dispose();
    super.dispose();
  }

  void _recompute() {
    final t = NutritionCalculator.targetKalori(
      beratKg: double.tryParse(_berat.text),
      tinggiCm: int.tryParse(_tinggi.text),
      umur: int.tryParse(_umur.text),
      jenisKelamin: _gender,
      aktivitas: _aktivitas,
      tujuan: _tujuan,
    );
    setState(() => _targetPreview = t);
  }

  Future<void> _save() async {
    final tinggi = int.tryParse(_tinggi.text);
    final berat = double.tryParse(_berat.text);
    final umur = int.tryParse(_umur.text);
    final budget = int.tryParse(_budget.text);

    final bodyErr = NutritionCalculator.validateBody(
      tinggiCm: tinggi,
      beratKg: berat,
      umur: umur,
    );
    if (bodyErr != null) {
      setState(() => _error = bodyErr);
      return;
    }
    final budgetErr = NutritionCalculator.validateBudget(budget);
    if (budgetErr != null) {
      setState(() => _error = budgetErr);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = await widget.auth.updateProfile(
        tinggiCm: tinggi,
        beratKg: berat,
        umur: umur,
        jenisKelamin: _gender,
        aktivitas: _aktivitas,
        tujuan: _tujuan,
        targetKalori: _targetPreview,
        targetBudgetIdr: budget,
      );
      if (!mounted) return;
      widget.onSaved(user);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil tersimpan.')),
      );
      Navigator.of(context).maybePop();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.auth.user;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(SonaSpacing.margin),
        children: [
          _header(u),
          const SizedBox(height: SonaSpacing.lg),
          _sectionTitle('Data Tubuh'),
          const SizedBox(height: SonaSpacing.sm),
          _numberField(_tinggi, 'Tinggi (cm)', Icons.height),
          const SizedBox(height: SonaSpacing.sm),
          _numberField(_berat, 'Berat (kg)', Icons.monitor_weight_outlined),
          const SizedBox(height: SonaSpacing.sm),
          _numberField(_umur, 'Umur (tahun)', Icons.cake_outlined),
          const SizedBox(height: SonaSpacing.lg),
          _sectionTitle('Jenis Kelamin'),
          const SizedBox(height: SonaSpacing.sm),
          _chips(
            options: const {'pria': 'Pria', 'wanita': 'Wanita'},
            selected: _gender,
            onSelect: (v) {
              _gender = v;
              _recompute();
            },
          ),
          const SizedBox(height: SonaSpacing.lg),
          _sectionTitle('Aktivitas Harian'),
          const SizedBox(height: SonaSpacing.sm),
          _chips(
            options: const {
              'ringan': 'Ringan',
              'sedang': 'Sedang',
              'berat': 'Berat',
            },
            selected: _aktivitas,
            onSelect: (v) {
              _aktivitas = v;
              _recompute();
            },
          ),
          const SizedBox(height: SonaSpacing.lg),
          _sectionTitle('Tujuan'),
          const SizedBox(height: SonaSpacing.sm),
          _chips(
            options: const {
              'turun': 'Turun BB',
              'jaga': 'Jaga BB',
              'naik': 'Naik BB',
            },
            selected: _tujuan,
            onSelect: (v) {
              _tujuan = v;
              _recompute();
            },
          ),
          const SizedBox(height: SonaSpacing.lg),
          _sectionTitle('Budget makan harian (Rp)'),
          const SizedBox(height: SonaSpacing.sm),
          _numberField(_budget, 'Budget harian', Icons.payments_outlined),
          const SizedBox(height: SonaSpacing.lg),
          _targetCard(),
          if (_usageToday != null) ...[
            const SizedBox(height: SonaSpacing.sm),
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 16, color: SonaColors.onSurfaceVariant),
                const SizedBox(width: SonaSpacing.xs),
              Text(
                'AI dipakai $_usageToday kali hari ini',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: SonaSpacing.md),
            Text(_error!, style: const TextStyle(color: SonaColors.error)),
          ],
          const SizedBox(height: SonaSpacing.lg),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: SonaColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SonaRadius.md),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: SonaColors.onPrimary),
                    )
                  : const Text('Simpan Profil'),
            ),
          ),
          const SizedBox(height: SonaSpacing.md),
          Center(
            child: TextButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout, size: 18, color: SonaColors.error),
              label: const Text('Keluar dari akun',
                  style: TextStyle(color: SonaColors.error)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(SonaUser? u) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: SonaColors.emeraldTint,
          backgroundImage:
              (u?.foto != null && u!.foto!.isNotEmpty) ? NetworkImage(u.foto!) : null,
          child: (u?.foto == null || u!.foto!.isEmpty)
              ? const Icon(Icons.person, size: 32, color: SonaColors.primary)
              : null,
        ),
        const SizedBox(width: SonaSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u?.nama ?? 'Pengguna Sona',
                  style: Theme.of(context).textTheme.titleMedium),
              if (u?.email != null)
                Text(u!.email!,
                    style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: SonaColors.onSurfaceVariant),
      );

  Widget _numberField(
      TextEditingController c, String label, IconData icon) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _recompute(),
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SonaRadius.md),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _chips({
    required Map<String, String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: SonaSpacing.sm,
      children: options.entries.map((e) {
        final on = e.key == selected;
        return ChoiceChip(
          label: Text(e.value),
          selected: on,
          onSelected: (_) => setState(() => onSelect(e.key)),
          selectedColor: Theme.of(context).colorScheme.primary,
          labelStyle: TextStyle(
            color: on
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        );
      }).toList(),
    );
  }

  Widget _targetCard() {
    final fmt = NumberFormat.decimalPattern('id_ID');
    return SonaCard(
      padding: const EdgeInsets.all(SonaSpacing.md),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Icon(Icons.local_fire_department,
                color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: SonaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Target kalori otomatis',
                    style: Theme.of(context).textTheme.labelSmall),
                Text(
                  _targetPreview == null
                      ? 'Lengkapi tinggi/berat/umur dulu'
                      : '${fmt.format(_targetPreview)} kkal / hari',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: SonaColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
