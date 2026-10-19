import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The playful hand-drawn shapes sprinkled around the UI.
enum DoodleKind { sparkle, heart, squiggle, confetti, starburst, ring }

/// A small decorative doodle drawn with a [CustomPainter].
///
/// Doodles are purely decorative, so they are hidden from screen readers.
class Doodle extends StatelessWidget {
  const Doodle({
    super.key,
    required this.kind,
    required this.color,
    this.size = 28,
    this.angle = 0,
  });

  final DoodleKind kind;
  final Color color;
  final double size;

  /// Rotation in radians.
  final double angle;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: angle,
        child: CustomPaint(
          size: Size.square(size),
          painter: _DoodlePainter(kind, color),
        ),
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter(this.kind, this.color);

  final DoodleKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, w * 0.07)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    switch (kind) {
      case DoodleKind.sparkle:
        // A four-pointed star with softly pinched sides.
        final path = Path()
          ..moveTo(w / 2, 0)
          ..quadraticBezierTo(w * 0.56, h * 0.44, w, h / 2)
          ..quadraticBezierTo(w * 0.56, h * 0.56, w / 2, h)
          ..quadraticBezierTo(w * 0.44, h * 0.56, 0, h / 2)
          ..quadraticBezierTo(w * 0.44, h * 0.44, w / 2, 0)
          ..close();
        canvas.drawPath(path, fill);

      case DoodleKind.heart:
        final path = Path()
          ..moveTo(w / 2, h * 0.88)
          ..cubicTo(w * 0.05, h * 0.58, w * 0.02, h * 0.18, w * 0.3, h * 0.14)
          ..cubicTo(w * 0.42, h * 0.12, w * 0.5, h * 0.24, w / 2, h * 0.32)
          ..cubicTo(w * 0.5, h * 0.24, w * 0.6, h * 0.1, w * 0.72, h * 0.14)
          ..cubicTo(w * 0.98, h * 0.2, w * 0.95, h * 0.6, w / 2, h * 0.88);
        canvas.drawPath(path, stroke);

      case DoodleKind.squiggle:
        final path = Path()..moveTo(0, h / 2);
        const waves = 3;
        final step = w / waves;
        for (var i = 0; i < waves; i++) {
          final x = i * step;
          path.quadraticBezierTo(
            x + step / 4,
            i.isEven ? h * 0.1 : h * 0.9,
            x + step / 2,
            h / 2,
          );
          path.quadraticBezierTo(
            x + step * 3 / 4,
            i.isEven ? h * 0.9 : h * 0.1,
            x + step,
            h / 2,
          );
        }
        canvas.drawPath(path, stroke);

      case DoodleKind.confetti:
        // A few short dashes radiating outwards, like a little celebration.
        const dashes = [
          [0.15, 0.55, 0.05, 0.25],
          [0.45, 0.35, 0.45, 0.05],
          [0.72, 0.5, 0.92, 0.25],
          [0.3, 0.95, 0.1, 0.8],
        ];
        for (final d in dashes) {
          canvas.drawLine(
            Offset(d[0] * w, d[1] * h),
            Offset(d[2] * w, d[3] * h),
            stroke,
          );
        }

      case DoodleKind.starburst:
        // A chunky, slightly irregular star.
        const points = 7;
        final center = Offset(w / 2, h / 2);
        final path = Path();
        for (var i = 0; i < points * 2; i++) {
          final radius = i.isEven ? w / 2 : w * (0.24 + (i % 3) * 0.03);
          final theta = (i * math.pi / points) - math.pi / 2;
          final point =
              center + Offset(math.cos(theta), math.sin(theta)) * radius;
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, fill);

      case DoodleKind.ring:
        // An open, hand-drawn looking ring.
        canvas.drawArc(
          Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.8, h * 0.8),
          math.pi * 0.15,
          math.pi * 1.6,
          false,
          stroke,
        );
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
