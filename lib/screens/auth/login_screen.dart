import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sona_components.dart';

/// Layar login opsional. User boleh melewati (skip) dan tetap memakai app.
///
/// Mendukung dua cara masuk: akun Google, atau email + password
/// (daftar/masuk). Tanpa login pun app tetap bisa dipakai.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.auth,
    required this.onDone,
    this.onSkip,
    this.notice,
    this.initialRegister = false,
  });

  final AuthService auth;
  final ValueChanged<SonaUser> onDone;
  final VoidCallback? onSkip;
  final String? notice;
  final bool initialRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nama = TextEditingController();

  bool _busy = false;
  bool _register = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _register = widget.initialRegister;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nama.dispose();
    super.dispose();
  }

  Future<void> _run(Future<SonaUser> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await action();
      if (!mounted) return;
      widget.onDone(user);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInGoogle() => _run(widget.auth.signInWithGoogle);

  Future<void> _signInEmail() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@')) {
      setState(() => _error = 'Masukkan email yang valid.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password minimal 6 karakter.');
      return;
    }
    await _run(() => widget.auth.signInWithEmail(
          email: email,
          password: password,
          nama: _nama.text,
          register: _register,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SonaSpacing.lg),
          children: [
            const SizedBox(height: SonaSpacing.lg),
            Center(
              child: Container(
                padding: const EdgeInsets.all(SonaSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1410B981),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const SonaLogo(size: 96, markOnly: true),
              ),
            ),
            const SizedBox(height: SonaSpacing.lg),
            Text(
              "Selamat datang di S'Meals",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: SonaSpacing.sm),
            Text(
              'Masuk untuk menyimpan catatan makanmu dan sinkron antar HP. '
              'Kamu tetap bisa memakai Sona tanpa login.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: SonaSpacing.lg),
            if (widget.notice != null && _error == null) ...[
              _banner(widget.notice!, SonaColors.amberTint, SonaColors.amberDeep),
              const SizedBox(height: SonaSpacing.md),
            ],
            if (_error != null) ...[
              _banner(_error!, SonaColors.error.withValues(alpha: 0.1),
                  SonaColors.error),
              const SizedBox(height: SonaSpacing.md),
            ],

            // ---- Google ----
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _busy ? null : _signInGoogle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SonaRadius.md),
                  ),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/google_logo.png',
                      height: 20,
                      width: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text('Lanjutkan dengan Google'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SonaSpacing.md),

            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SonaSpacing.sm),
                  child: Text('atau',
                      style: Theme.of(context).textTheme.labelSmall),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: SonaSpacing.md),

            // ---- Email + password ----
            if (_register) ...[
              TextField(
                controller: _nama,
                textInputAction: TextInputAction.next,
                decoration: _dec('Nama (opsional)', Icons.person_outline),
              ),
              const SizedBox(height: SonaSpacing.sm),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: _dec('Email', Icons.mail_outline),
            ),
            const SizedBox(height: SonaSpacing.sm),
            TextField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _signInEmail(),
              decoration: _dec('Password', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                      size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: SonaSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _busy ? null : _signInEmail,
                style: FilledButton.styleFrom(
                  backgroundColor: SonaColors.primary,
                  foregroundColor: SonaColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SonaRadius.md),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: SonaColors.onPrimary),
                      )
                    : Text(_register ? 'Daftar akun baru' : 'Masuk'),
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _register = !_register;
                        _error = null;
                      }),
              child: Text(_register
                  ? 'Sudah punya akun? Masuk'
                  : 'Belum punya akun? Daftar'),
            ),
            const SizedBox(height: SonaSpacing.sm),
            TextButton(
              onPressed: _busy ? null : widget.onSkip,
              child: const Text('Lewati dulu, pakai tanpa login'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SonaRadius.md),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SonaRadius.md),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SonaRadius.md),
          borderSide:
              BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
      );

  Widget _banner(String text, Color bg, Color fg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SonaSpacing.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(SonaRadius.sm),
        ),
        child: Text(text, textAlign: TextAlign.center,
            style: TextStyle(color: fg)),
      );
}
