import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/sona_store.dart';
import 'domain/budget_recommender.dart';
import 'models/meal_log.dart';
import 'screens/account/account_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/consult/consult_screen.dart';
import 'screens/help/help_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/menus/menus_screen.dart';
import 'screens/notes/meal_detail_screen.dart';
import 'screens/notes/notes_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/scan/scan_screen.dart';
import 'screens/settings/reminder_screen.dart';
import 'services/notification_service.dart';
import 'services/ai_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'widgets/sona_components.dart';
import 'widgets/sona_page_route.dart';

void main() {
  runApp(const SonaApp());
}

enum SonaTab { home, menus, scan, consult, notes }

class SonaApp extends StatefulWidget {
  const SonaApp({super.key});

  @override
  State<SonaApp> createState() => _SonaAppState();
}

class _SonaAppState extends State<SonaApp> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "S'Meals",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _mode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id'), Locale('en')],
      locale: const Locale('id'),
      home: _Bootstrap(onThemeModeChanged: (m) => setState(() => _mode = m)),
    );
  }
}

ThemeMode themeModeFromKey(String key) => switch (key) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

/// Menyiapkan store (SharedPreferences) sebelum app tampil.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap({this.onThemeModeChanged});

  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<SonaStore> _future;
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    _future = SonaStore.open().then((store) {
      widget.onThemeModeChanged?.call(themeModeFromKey(store.themeMode));
      return store;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SonaStore>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Gagal memuat data: ${snapshot.error}'),
              ),
            ),
          );
        }
        // Splash = tampilan pertama aplikasi; animasi berjalan sementara
        // store (SharedPreferences) dibuka di belakangnya.
        if (!_splashDone) {
          return SplashScreen(onDone: () {
            if (mounted) setState(() => _splashDone = true);
          });
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _Root(
          store: snapshot.data!,
          onThemeModeChanged: widget.onThemeModeChanged,
        );
      },
    );
  }
}

class _Root extends StatefulWidget {
  const _Root({required this.store, this.onThemeModeChanged});
  final SonaStore store;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final AiService _ai = AiService();
  final AuthService _auth = AuthService();
  SonaTab _tab = SonaTab.home;
  bool _showLogin = true;
  bool _restored = false;
  String? _loginNotice;
  bool _loggingOut = false;
  int _scanCameraRequest = 0;

  /// Buka tab Pindai; nonce-nya meminta kamera langsung dibuka.
  void _openScan() {
    setState(() {
      _tab = SonaTab.scan;
      _scanCameraRequest++;
    });
  }

  void _onNavSelect(SonaTab t) {
    if (t == SonaTab.scan) {
      _openScan();
      return;
    }
    setState(() => _tab = t);
  }

  static const _titles = {
    SonaTab.home: 'Beranda',
    SonaTab.menus: 'Ide Menu',
    SonaTab.scan: 'Pindai',
    SonaTab.consult: 'Konsultasi',
    SonaTab.notes: 'Catatan',
  };

  @override
  void initState() {
    super.initState();
    widget.store.attachAuth(_auth);
    _auth.onExpired = _onAuthExpired;
    NotificationService.instance.init();
    _syncReminders();
    _restore();
    _loadFoods();
  }

  /// Sinkronkan jadwal notifikasi ke jam tersimpan (bila pengingat aktif).
  Future<void> _syncReminders() async {
    if (!widget.store.remindersEnabled) return;
    try {
      await NotificationService.instance
          .scheduleReminders(widget.store.reminderTimes);
    } catch (_) {
      // Best-effort: jadwal lama tetap berjalan bila gagal.
    }
  }

  /// Muat tabel master makanan untuk rekomendasi budget (best-effort).
  Future<void> _loadFoods() async {
    await widget.store.refreshFoods();
    if (mounted) setState(() {});
  }

  /// Catat makanan rekomendasi langsung ke catatan hari ini.
  Future<void> _pickFood(FoodPick pick) async {
    final meal = MealLog(
      id: 'rec${DateTime.now().microsecondsSinceEpoch}',
      name: pick.nama,
      calories: pick.kalori,
      proteinG: pick.proteinG,
      carbsG: 0,
      fatG: 0,
      sugarG: 0,
      saltG: 0,
      score: MealScore.b,
      createdAt: DateTime.now(),
      priceIdr: pick.hargaIdr,
      waktuMakan: MealTime.fromHour(DateTime.now().hour),
    );
    await widget.store.addMeal(meal);
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${pick.nama} ditambahkan ke catatan')),
    );
  }

  /// Dipanggil saat server menyatakan token kedaluwarsa.
  void _onAuthExpired() {
    // Sesi berakhir = keluar akun: hapus semua data lokal.
    widget.store.clearAccountData();
    if (!mounted) return;
    setState(() {
      _showLogin = true;
      _loginNotice = 'Sesi kamu sudah berakhir. Silakan masuk lagi.';
      _tab = SonaTab.home;
    });
  }

  /// Pulihkan sesi tersimpan; kalau ada, lewati layar login.
  Future<void> _restore() async {
    final token = widget.store.loadAuthToken();
    if (token != null && token.isNotEmpty) {
      final user = await _auth.restore(token);
      if (user != null && mounted) {
        await widget.store.setDisplayName(user.nama);
        await widget.store.setCalorieTarget(user.targetKalori);
        await widget.store.setDailyBudgetIdr(user.targetBudgetIdr);
        await widget.store.refreshFromServer();
        if (mounted) {
          setState(() {
            _showLogin = false;
            _loginNotice = null;
          });
        }
        if (mounted) setState(() => _restored = true);
        return;
      }
    }
    if (mounted) setState(() => _restored = true);
  }

  Future<void> _onLoggedIn(SonaUser user) async {
    // Login = mulai dari data akun ini di DB. Data lokal (termasuk catatan
    // tamu yang belum pernah login) TIDAK dikirim ke server — bersihkan
    // dulu, lalu tarik catatan milik akun ini saja supaya tidak tercampur.
    await widget.store.clearAccountData();
    await widget.store.saveAuthToken(_auth.token);
    await widget.store.setDisplayName(user.nama);
    await widget.store.setCalorieTarget(user.targetKalori);
    await widget.store.setDailyBudgetIdr(user.targetBudgetIdr);
    await widget.store.setWeightKg(user.beratKg);
    await widget.store.syncFromServer();
    if (!mounted) return;
    setState(() {
      _showLogin = false;
      _loginNotice = null;
      _tab = SonaTab.home;
    });
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await _auth.signOut();
      // Keluar akun: hapus semua memori lokal (catatan, chat, profil).
      await widget.store.clearAccountData();
    } catch (_) {}
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _loggingOut = false;
      _showLogin = true;
      _loginNotice = null;
      _tab = SonaTab.home;
    });
  }

  Future<void> _openProfile() async {
    if (!_auth.isLoggedIn) {
      await _openLogin();
      return;
    }
    await Navigator.of(context).push(
      SonaFadeSlideRoute(
        builder: (_) => ProfileScreen(
          auth: _auth,
          onSaved: _onProfileSaved,
          onLogout: () {
            Navigator.of(context).maybePop();
            _logout();
          },
        ),
      ),
    );
  }

  Future<void> _openLogin({bool register = false}) async {
    await Navigator.of(context).push(
      SonaFadeSlideRoute(
        builder: (ctx) => LoginScreen(
          auth: _auth,
          initialRegister: register,
          onDone: (user) async {
            Navigator.of(ctx).pop();
            await _onLoggedIn(user);
          },
          onSkip: () => Navigator.of(ctx).maybePop(),
        ),
      ),
    );
  }

  Future<void> _openAccount() async {
    if (!_auth.isLoggedIn) {
      await _openLogin();
      return;
    }
    await Navigator.of(context).push(
      SonaFadeSlideRoute(
        builder: (ctx) => AccountScreen(
          auth: _auth,
          store: widget.store,
          onLogin: () => _openLogin(),
          onRegister: () => _openLogin(register: true),
          onProfile: _openProfile,
          onReminders: _openReminders,
          onHelp: _openHelp,
          onLogout: () async {
            Navigator.of(ctx).maybePop();
            await _logout();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openHelp() async {
    await Navigator.of(context).push(SonaFadeSlideRoute(builder: (_) => const HelpScreen()));
  }

  Future<void> _openReminders() async {
    await Navigator.of(context).push(SonaFadeSlideRoute(builder: (_) => ReminderScreen(store: widget.store)));
  }

  Future<void> _openMeal(MealLog meal) async {
    await Navigator.of(context).push(
      SonaFadeSlideRoute(
        builder: (_) => MealDetailScreen(
          store: widget.store,
          meal: meal,
          onChanged: _refresh,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _editTargets() async {
    final cal = TextEditingController(
      text: widget.store.calorieTarget > 0
          ? widget.store.calorieTarget.toString()
          : '',
    );
    final budget = TextEditingController(
      text: widget.store.dailyBudgetIdr > 0
          ? widget.store.dailyBudgetIdr.toString()
          : '',
    );
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Target Harian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cal,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target kalori',
                suffixText: 'kkal',
              ),
            ),
            const SizedBox(height: SonaSpacing.sm),
            TextField(
              controller: budget,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Budget makan',
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final c = int.tryParse(cal.text.trim()) ??
                  widget.store.calorieTarget;
              final b =
                  int.tryParse(budget.text.trim()) ?? widget.store.dailyBudgetIdr;
              Navigator.pop(ctx, (c, b));
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    cal.dispose();
    budget.dispose();
    if (result == null || !mounted) return;
    final (newCal, newBudget) = result;
    if (newCal > 0) await widget.store.setCalorieTarget(newCal);
    if (newBudget > 0) await widget.store.setDailyBudgetIdr(newBudget);
    if (_auth.isLoggedIn) {
      try {
        final user = await _auth.updateProfile(
          targetKalori: newCal > 0 ? newCal : null,
          targetBudgetIdr: newBudget > 0 ? newBudget : null,
        );
        await widget.store.setCalorieTarget(user.targetKalori);
        await widget.store.setDailyBudgetIdr(user.targetBudgetIdr);
      } catch (_) {
        // Simpan lokal tetap berhasil walau sinkron gagal.
      }
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Target harian diperbarui')),
    );
  }

  Future<void> _onProfileSaved(SonaUser user) async {
    await widget.store.setDisplayName(user.nama);
    await widget.store.setCalorieTarget(user.targetKalori);
    await widget.store.setDailyBudgetIdr(user.targetBudgetIdr);
    await widget.store.setWeightKg(user.beratKg);
    if (mounted) setState(() {});
  }

  Future<void> _openMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.account_circle_outlined, color: SonaColors.primary),
              title: const Text('Akun'),
              subtitle: Text(_auth.isLoggedIn
                  ? (_auth.user?.email ?? 'Sudah masuk')
                  : 'Masuk untuk mengakses akun'),
              onTap: () {
                Navigator.pop(ctx);
                if (_auth.isLoggedIn) {
                  _openAccount();
                } else {
                  _openLogin();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: SonaColors.primary),
              title: const Text('Profil & Target Gizi'),
              onTap: () {
                Navigator.pop(ctx);
                if (!_auth.isLoggedIn) {
                  _openLogin();
                } else {
                  _openProfile();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none, color: SonaColors.primary),
              title: const Text('Pengingat Makan & Minum'),
              onTap: () {
                Navigator.pop(ctx);
                _openReminders();
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: SonaColors.primary),
              title: const Text('Bantuan & FAQ'),
              onTap: () {
                Navigator.pop(ctx);
                _openHelp();
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined,
                  color: SonaColors.primary),
              title: const Text('Tema tampilan'),
              subtitle: Text(_themeLabel()),
              onTap: () {
                Navigator.pop(ctx);
                _cycleTheme();
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _themeOrder = ['system', 'light', 'dark'];
  static const _themeLabels = {
    'system': 'Ikut sistem',
    'light': 'Terang',
    'dark': 'Gelap',
  };

  String _themeLabel() => _themeLabels[widget.store.themeMode] ?? 'Ikut sistem';

  Future<void> _cycleTheme() async {
    final cur = widget.store.themeMode;
    final idx = _themeOrder.indexOf(cur);
    final next = _themeOrder[(idx + 1) % _themeOrder.length];
    await widget.store.setThemeMode(next);
    widget.onThemeModeChanged?.call(themeModeFromKey(next));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ai.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!_restored) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SonaLogo(size: 64, markOnly: true),
              const SizedBox(height: SonaSpacing.md),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_loggingOut) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SonaLogo(size: 72, markOnly: true),
              const SizedBox(height: SonaSpacing.md),
              const CircularProgressIndicator(),
              const SizedBox(height: SonaSpacing.sm),
              Text('Keluar dari akun...',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    if (_showLogin) {
      return LoginScreen(
        auth: _auth,
        onDone: _onLoggedIn,
        onSkip: () => setState(() {
          _showLogin = false;
          _loginNotice = null;
        }),
        notice: _loginNotice,
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          SonaTopBar(
            title: _titles[_tab]!,
            onMenu: _openMenu,
            onProfile: _openAccount,
            onHelp: _openHelp,
            onNotifications: _openReminders,
            avatarUrl: _auth.user?.foto,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _SonaBottomNav(
        active: _tab,
        onSelect: _onNavSelect,
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case SonaTab.home:
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 340),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.015, 0.012),
                      end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
              child: ScaleTransition(
                scale: Tween(begin: 0.985, end: 1.0).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
          ),
          child: HomeScreen(
            key: const ValueKey(SonaTab.home),
          name: widget.store.displayName,
          summary: widget.store.todaySummary(),
          recent: widget.store.loadMeals().take(5).toList(),
          streak: widget.store.streak,
          calorieTarget: widget.store.calorieTarget,
          budgetIdr: widget.store.dailyBudgetIdr,
          budgetPicks: widget.store.budgetPicks(),
          sisaBudgetIdr: widget.store.budgetSisaIdr,
          onPickFood: _pickFood,
          onScan: _openScan,
          onRecipes: () => setState(() => _tab = SonaTab.menus),
          onBudget: () => setState(() => _tab = SonaTab.notes),
          onHistory: () => setState(() => _tab = SonaTab.notes),
          onEditTarget: _editTargets,
          onOpenMeal: _openMeal,
          ),
        );
      case SonaTab.menus:
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 340),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.01, 0),
                      end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: MenusScreen(key: const ValueKey(SonaTab.menus), ai: _ai),
        );
      case SonaTab.scan:
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.01, 0),
                      end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: ScanScreen(
            key: const ValueKey(SonaTab.scan),
            store: widget.store,
            ai: _ai,
            onSaved: _refresh,
            cameraRequest: _scanCameraRequest,
          ),
        );
      case SonaTab.consult:
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.01, 0),
                      end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: ConsultScreen(
              key: const ValueKey(SonaTab.consult), store: widget.store, ai: _ai),
        );
      case SonaTab.notes:
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.01, 0),
                      end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: NotesScreen(
              key: const ValueKey(SonaTab.notes), store: widget.store, onChanged: _refresh),
        );
    }
  }
}

class _SonaBottomNav extends StatelessWidget {
  const _SonaBottomNav({required this.active, required this.onSelect});

  final SonaTab active;
  final ValueChanged<SonaTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.home,
                      label: 'Beranda',
                      selected: active == SonaTab.home,
                      onTap: () => onSelect(SonaTab.home),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.restaurant_menu,
                      label: 'Menu',
                      selected: active == SonaTab.menus,
                      onTap: () => onSelect(SonaTab.menus),
                    ),
                  ),
                  const SizedBox(width: 72),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.smart_toy_outlined,
                      label: 'Tanya',
                      selected: active == SonaTab.consult,
                      onTap: () => onSelect(SonaTab.consult),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.edit_calendar_outlined,
                      label: 'Catatan',
                      selected: active == SonaTab.notes,
                      onTap: () => onSelect(SonaTab.notes),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: -18,
                left: 0,
                right: 0,
                child: Center(
                  child: _ScanFab(
                    active: active == SonaTab.scan,
                    onTap: () => onSelect(SonaTab.scan),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanFab extends StatefulWidget {
  const _ScanFab({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  State<_ScanFab> createState() => _ScanFabState();
}

class _ScanFabState extends State<_ScanFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final breathe =
              1.0 + 0.03 * Curves.easeInOut.transform(_pulse.value);
          final base = widget.active ? 1.0 : 0.94;
          return Transform.scale(scale: base * breathe, child: child);
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [SonaColors.primary, SonaColors.primaryContainer],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x5910B981),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.document_scanner,
              size: 26, color: SonaColors.onPrimary),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(icon, size: 23, color: color),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                        color: color,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      ) ??
                  TextStyle(color: color),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
