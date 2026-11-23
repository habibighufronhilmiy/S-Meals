import 'package:flutter/material.dart';

/// Entrance lembut: fade + geser ke atas, dimainkan sekali saat pertama
/// tampil. Beri [delay] berbeda tiap elemen untuk efek bertahap (stagger).
class SonaEntrance extends StatefulWidget {
  const SonaEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.dy = 14,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final Duration delay;
  final double dy;
  final Duration duration;

  @override
  State<SonaEntrance> createState() => _SonaEntranceState();
}

class _SonaEntranceState extends State<SonaEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.dy * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
