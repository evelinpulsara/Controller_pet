import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/pet_palette.dart';

class Confetti extends StatefulWidget {
  const Confetti({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  final _rnd = Random();
  late final List<_Piece> _pieces = List.generate(
    90,
    (_) => _Piece(
      x: _rnd.nextDouble(),
      delay: _rnd.nextDouble() * 0.35,
      speed: 0.7 + _rnd.nextDouble() * 0.6,
      drift: (_rnd.nextDouble() - 0.5) * 0.25,
      spin: (_rnd.nextDouble() - 0.5) * 12,
      size: 6 + _rnd.nextDouble() * 7,
      color: PetPalette.all[_rnd.nextInt(PetPalette.all.length)],
      round: _rnd.nextBool(),
    ),
  );

  @override
  void initState() {
    super.initState();
    _a.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _a.value)),
      ),
    );
  }
}

class _Piece {
  _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });
  final double x, delay, speed, drift, spin, size;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + (size.height + 40) * local * p.speed;
      final x = size.width * (p.x + p.drift * local) + sin(local * 10 + p.x * 6) * 14;
      final paint = Paint()..color = p.color.withValues(alpha: (1 - local * 0.6));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
                const Radius.circular(2)),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter o) => true;
}
