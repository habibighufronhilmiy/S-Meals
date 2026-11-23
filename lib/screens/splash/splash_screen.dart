import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/sona_components.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 580),
  );

  late final Animation<double> _logoScale = Tween(begin: 0.7, end: 1.0).animate(
    CurvedAnimation(parent: _in, curve: Curves.easeOutBack),
  );
  late final Animation<double> _logoFade = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _in, curve: Curves.easeIn),
  );
  late final Animation<double> _textFade = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(
        parent: _in, curve: const Interval(0.3, 1.0, curve: Curves.easeIn)),
  );
  late final Animation<Offset> _textSlide = Tween(
    begin: const Offset(0, 0.22),
    end: Offset.zero,
  ).animate(CurvedAnimation(
      parent: _in, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));

  late final Animation<double> _outFade = Tween(begin: 1.0, end: 0.0).animate(
    CurvedAnimation(parent: _out, curve: Curves.easeInOut),
  );
  late final Animation<double> _outScale = Tween(begin: 1.0, end: 0.9).animate(
    CurvedAnimation(parent: _out, curve: Curves.easeInOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 30));
    if (!mounted) return;
    try {
      await _in.forward().timeout(const Duration(milliseconds: 1400));
    } catch (_) {}
    if (!mounted) return;
    try {
      await _hold.forward().timeout(const Duration(milliseconds: 900));
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    try {
      await _out.forward().timeout(const Duration(milliseconds: 1000));
    } catch (_) {}
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _in.dispose();
    _hold.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AnimatedBuilder(
        animation: _out,
        builder: (context, child) {
          return FadeTransition(
            opacity: _outFade,
            child: ScaleTransition(scale: _outScale, child: child),
          );
        },
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        padding: const EdgeInsets.all(SonaSpacing.lg),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLowest
                              : SonaColors.surfaceContainerLowest,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0x3322C55E)
                                  : const Color(0x1810B981),
                              blurRadius: 34,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: const SonaLogo(size: 118, markOnly: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: SonaSpacing.lg),
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          Text(
                            "S'Meals",
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Asisten gizi & budget makan anak kos',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 18,
              child: FadeTransition(
                opacity: _textFade,
                child: Text(
                  'Memuat...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
