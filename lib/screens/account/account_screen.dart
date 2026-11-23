import 'package:flutter/material.dart';

import '../../data/sona_store.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sona_components.dart';

/// Halaman akun: status masuk, ringkasan target, dan pintasan pengaturan.
class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.auth,
    required this.store,
    required this.onLogin,
    required this.onRegister,
    required this.onProfile,
    required this.onReminders,
    required this.onHelp,
    required this.onLogout,
  });

  final AuthService auth;
  final SonaStore store;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onProfile;
  final VoidCallback onReminders;
  final VoidCallback onHelp;
  final Future<void> Function() onLogout;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  int? _usage;

  @override
  void initState() {
    super.initState();
    if (widget.auth.isLoggedIn) _loadUsage();
    widget.auth.onExpired = () {
      if (mounted) setState(() {});
    };
  }

  Future<void> _loadUsage() async {
    final n = await widget.auth.fetchUsageToday();
    if (mounted) setState(() => _usage = n);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    final logged = widget.auth.isLoggedIn;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Akun'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            SonaSpacing.margin, SonaSpacing.sm, SonaSpacing.margin, SonaSpacing.lg),
        children: [
          if (logged) _profileHeader(user) else _guestHeader(),
          const SizedBox(height: SonaSpacing.md),
          if (!logged) ...[
            SonaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text('Masuk untuk mencadangkan catatanmu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                  const SizedBox(height: 4),
                  Text(
                    'Data tetap bisa dipakai tanpa login. Dengan akun, catatan '
                    'tersinkron antar HP dan target gizimu tersimpan aman.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: SonaSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: widget.onLogin,
                          style: FilledButton.styleFrom(
                            backgroundColor: SonaColors.primary,
                            foregroundColor: SonaColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(SonaRadius.md),
                            ),
                          ),
                          child: const Text('Masuk'),
                        ),
                      ),
                      const SizedBox(width: SonaSpacing.sm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onRegister,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SonaColors.primary,
                            side: const BorderSide(
                                color: SonaColors.primary, width: 1.4),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(SonaRadius.md),
                            ),
                          ),
                          child: const Text('Daftar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: SonaSpacing.md),
          ],
          if (logged) ...[
            SonaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ringkasan target',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: SonaSpacing.sm),
                  _statRow(
                    Icons.local_fire_department,
                    'Target kalori',
                    '${widget.store.calorieTarget} kkal / hari',
                  ),
                  const SizedBox(height: SonaSpacing.sm),
                  _statRow(
                    Icons.savings_outlined,
                    'Budget makan',
                    'Rp ${widget.store.dailyBudgetIdr} / hari',
                  ),
                  const SizedBox(height: SonaSpacing.sm),
                  _statRow(
                    Icons.auto_awesome,
                    'AI hari ini',
                    _usage == null ? 'Menghitung...' : '$_usage kali',
                  ),
                ],
              ),
            ),
            const SizedBox(height: SonaSpacing.md),
            SonaCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _tile(Icons.person_outline, 'Profil & Target Gizi',
                      widget.onProfile),
                  _divider(),
                  _tile(Icons.notifications_none, 'Pengingat Makan & Minum',
                      widget.onReminders),
                  _divider(),
                  _tile(Icons.help_outline, 'Bantuan & FAQ', widget.onHelp),
                  _divider(),
                  _tile(
                    Icons.logout,
                    'Keluar dari akun',
                    () async {
                      await widget.onLogout();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    danger: true,
                  ),
                ],
              ),
            ),
          ] else ...[
            SonaCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _tile(Icons.notifications_none, 'Pengingat Makan & Minum',
                      widget.onReminders),
                  _divider(),
                  _tile(Icons.help_outline, 'Bantuan & FAQ', widget.onHelp),
                ],
              ),
            ),
          ],
          const SizedBox(height: SonaSpacing.lg),
          Text(
            "S'Meals • data lokal aman di perangkatmu.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _profileHeader(SonaUser? user) {
    return SonaCard(
      child: Row(
        children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: (user?.foto != null && user!.foto!.isNotEmpty)
                    ? NetworkImage(user.foto!)
                    : null,
                child: (user?.foto == null || user!.foto!.isEmpty)
                    ? Icon(Icons.person,
                        size: 30, color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
          const SizedBox(width: SonaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.nama ?? 'Pengguna',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                if (user?.email != null)
                  Text(user!.email!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                const SizedBox(height: 2),
                Text('Sudah masuk',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guestHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SonaSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SonaRadius.md),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SonaColors.emeraldTint, SonaColors.amberTint],
        ),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(Icons.person_outline,
                size: 30, color: SonaColors.primary),
          ),
          const SizedBox(height: SonaSpacing.sm),
          Text('Belum masuk',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 2),
          Text('Catatan tersimpan di HP ini saja.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: SonaColors.onSurfaceVariant),
        const SizedBox(width: SonaSpacing.sm),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
      ],
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap,
      {bool danger = false}) {
    return ListTile(
      leading: Icon(icon,
          color: danger
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary),
      title: Text(title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              )),
      trailing: Icon(Icons.chevron_right,
          size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }

  Widget _divider() => Divider(
        height: 1,
        color: SonaColors.outlineVariant.withValues(alpha: 0.3),
      );
}
