import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Kartu permukaan standar ala Stitch: putih bersih, radius 12, bayangan
/// lembut bernuansa emerald.
class SonaCard extends StatefulWidget {
  const SonaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SonaSpacing.md),
    this.color,
    this.onTap,
    this.enableScale = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool enableScale;

  @override
  State<SonaCard> createState() => _SonaCardState();
}

class _SonaCardState extends State<SonaCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    reverseDuration: const Duration(milliseconds: 130),
  );
  late final Animation<double> _scale = Tween(begin: 1.0, end: 0.985).animate(
    CurvedAnimation(parent: _c, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) {
    if (widget.onTap != null && widget.enableScale) _c.forward();
  }

  void _up(_) {
    if (widget.enableScale) _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.color ??
        (isDark
            ? Theme.of(context).colorScheme.surfaceContainerHigh
            : SonaColors.surfaceContainerLowest);
    final card = Container(
      width: double.infinity,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SonaRadius.md),
        border: Border.all(
            color: isDark
                ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55)
                : SonaColors.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0x2214F59E)
                : const Color(0x1410B981),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: widget.child,
    );
    if (widget.onTap == null) return card;
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: ScaleTransition(
        scale: _scale,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(SonaRadius.md),
            onTap: widget.onTap,
            child: card,
          ),
        ),
      ),
    );
  }
}

/// Chip/pill kecil untuk label (mis. "18g Protein").
class SonaPill extends StatelessWidget {  const SonaPill({
    super.key,
    required this.text,
    this.background = SonaColors.emeraldTint,
    this.foreground = SonaColors.primary,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SonaRadius.full),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

/// Batang progres linear bergaya Stitch.
class SonaProgressBar extends StatelessWidget {
  const SonaProgressBar({
    super.key,
    required this.fraction,
    this.color = SonaColors.primaryContainer,
    this.trackColor = SonaColors.surfaceVariant,
    this.height = 8,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(SonaRadius.full),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: trackColor),
            FractionallySizedBox(
              widthFactor: clamped,
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu baris makronutrisi: label, nilai, dan bar.
class MacroBar extends StatefulWidget {
  const MacroBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    required this.barColor,
  });

  final String label;
  final String value;
  final double fraction;
  final Color barColor;

  @override
  State<MacroBar> createState() => _MacroBarState();
}

class _MacroBarState extends State<MacroBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _anim =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clamped = widget.fraction.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                    ),
              ),
            ),
            Text(
              widget.value,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: widget.barColor,
                    fontSize: 12,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(SonaRadius.full),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest),
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) => FractionallySizedBox(
                    widthFactor: clamped * _anim.value,
                    child: Container(color: widget.barColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Header persisten ala Stitch: logo + judul halaman + bell + avatar.
class SonaTopBar extends StatelessWidget {
  const SonaTopBar({
    super.key,
    required this.title,
    this.onMenu,
    this.onAccount,
    this.onProfile,
    this.onHelp,
    this.onNotifications,
    this.avatarUrl,
  });

  final String title;
  final VoidCallback? onMenu;
  final VoidCallback? onAccount;
  final VoidCallback? onProfile;
  final VoidCallback? onHelp;
  final VoidCallback? onNotifications;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: SonaSpacing.md,
        right: SonaSpacing.md,
        bottom: 12,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenu,
            icon: Icon(Icons.menu,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const _SonaLogo(),
          const SizedBox(width: SonaSpacing.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          IconButton(
            tooltip: 'Bantuan & FAQ',
            onPressed: onHelp,
            icon: Icon(Icons.help_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          IconButton(
            tooltip: 'Pengingat',
            onPressed: onNotifications,
            icon: Icon(Icons.notifications_none,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          GestureDetector(
            onTap: onProfile ?? onAccount,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [SonaColors.primaryContainer, SonaColors.secondaryContainer],
                ),
              ),
              child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl!,
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const Icon(
                            Icons.person,
                            size: 18,
                            color: SonaColors.onPrimaryContainer),
                      ),
                    )
                  : const Icon(Icons.person,
                      size: 18, color: SonaColors.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _SonaLogo extends StatelessWidget {
  const _SonaLogo();

  @override
  Widget build(BuildContext context) {
    return const SonaLogo(size: 30, markOnly: true);
  }
}

/// Logo Sona yang otomatis memilih varian sesuai mode terang/gelap.
class SonaLogo extends StatelessWidget {
  const SonaLogo({super.key, this.size = 32, this.markOnly = true});

  final double size;
  final bool markOnly;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final path = markOnly
        ? (isDark ? 'assets/logo_mark_dark.png' : 'assets/logo_mark_light.png')
        : (isDark ? 'assets/logo_dark.png' : 'assets/logo_light.png');
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Tampilan kosong yang seragam (ikon + judul + pesan + aksi opsional).
class SonaEmptyState extends StatelessWidget {
  const SonaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SonaSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: SonaColors.emeraldTint,
              ),
              child: Icon(icon, size: 34, color: SonaColors.primary),
            ),
            const SizedBox(height: SonaSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SonaColors.onSurface,
                  ),
            ),
            if (message != null) ...[
              const SizedBox(height: SonaSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SonaColors.onSurfaceVariant,
                    ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: SonaSpacing.md),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: SonaColors.primary,
                  foregroundColor: SonaColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SonaRadius.md),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tampilan galat yang seragam dengan tombol "Coba lagi".
class SonaErrorView extends StatelessWidget {
  const SonaErrorView({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SonaSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: SonaColors.error),
            const SizedBox(height: SonaSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SonaColors.onSurfaceVariant,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: SonaSpacing.sm),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ubah error teknis (SocketException/TimeoutException/HTTP) menjadi pesan
/// ramah pengguna yang konsisten di seluruh app.
String friendlyError(Object error) {
  final s = error.toString().toLowerCase();
  if (s.contains('timeout') || s.contains('timed out')) {
    return 'Koneksi lambat. Coba lagi sebentar ya.';
  }
  if (s.contains('socket') ||
      s.contains('network') ||
      s.contains('failed host') ||
      s.contains('connection')) {
    return 'Tidak ada koneksi internet. Periksa jaringamu.';
  }
  if (s.contains('401')) return 'Sesi kamu sudah berakhir. Masuk lagi ya.';
  if (s.contains('429')) return 'Terlalu banyak permintaan. Tunggu sebentar.';
  if (s.contains('5')) return 'Server sedang sibuk. Coba lagi nanti.';
  return 'Terjadi kesalahan. Coba lagi ya.';
}
