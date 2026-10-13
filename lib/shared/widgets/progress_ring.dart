import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Anillo de progreso hacia la meta diaria (se llena con animación).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 120,
    this.stroke = 12,
    this.child,
  });
  final double progress; // 0..1 (puede pasar de 1)
  final Color color;
  final double size, stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0, 1.0)),
        duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, p, _) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(p, color, context.colors.line, stroke),
            child: Center(child: child),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p, this.color, this.track, this.stroke);
  final double p, stroke;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.shortestSide - stroke) / 2;
    final c = size.center(Offset.zero);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(c, r, base);
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * p, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.p != p || o.color != color || o.track != track;
}

/// Gráfico de barras de la semana (una barra por día).
class WeekBars extends StatelessWidget {
  const WeekBars({
    super.key,
    required this.values,
    required this.labels,
    required this.goal,
    required this.color,
    this.highlightLast = true,
    this.height = 140,
    this.sample = const [],
  });
  final List<double> values;
  final List<String> labels;
  final double goal;
  final Color color;
  final bool highlightLast;
  final double height;
  /// Qué días son datos de ejemplo (se dibujan rayados/claros).
  final List<bool> sample;

  @override
  Widget build(BuildContext context) {
    final maxV = [goal, ...values].reduce(max);
    return SizedBox(
      height: height + 24,
      child: Stack(children: [
        // Línea de la meta
        Positioned(
          left: 0,
          right: 0,
          top: maxV <= 0 ? 0 : height * (1 - goal / maxV),
          child: Container(height: 1.5, color: color.withValues(alpha: 0.35)),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: maxV <= 0 ? 0 : values[i] / maxV),
                  duration: reduceMotion(context) ? Duration.zero : Duration(milliseconds: 500 + i * 70),
                  curve: Curves.easeOutCubic,
                  builder: (_, f, _) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    height: max(4, height * f),
                    decoration: BoxDecoration(
                      color: (highlightLast && i == values.length - 1)
                          ? color
                          : color.withValues(alpha: (i < sample.length && sample[i]) ? 0.25 : 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == values.length - 1 ? FontWeight.w800 : FontWeight.w600,
                      color: i == values.length - 1 ? context.colors.ink : context.colors.muted,
                    )),
              ]),
            ),
        ]),
      ]),
    );
  }
}
