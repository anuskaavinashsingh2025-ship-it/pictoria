import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Soft abstract pastel shapes painted behind a screen's content.
///
/// [progress] is a continuous value (for onboarding, the current page as a
/// double) that gently drifts the shapes as the user swipes between pages.
class PastelBackdrop extends StatelessWidget {
  const PastelBackdrop({super.key, this.progress = 0, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BackdropPainter(progress), child: child);
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final drift = progress * 0.6;

    // Large lavender arc sweeping in from the top right.
    final arcPaint = Paint()
      ..color = AppColors.lavender.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.98, h * 0.2), radius: w * 0.32),
      math.pi * (0.95 + drift * 0.2),
      math.pi * 0.95,
      false,
      arcPaint,
    );

    // Peach blob in the lower left.
    final peach = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.peach.withValues(alpha: 0.55),
              AppColors.peach.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(w * (0.05 + drift * 0.1), h * 0.82),
              radius: w * 0.55,
            ),
          );
    canvas.drawCircle(
      Offset(w * (0.05 + drift * 0.1), h * 0.82),
      w * 0.55,
      peach,
    );

    // Butter-yellow glow near the top left, behind the headline.
    final butter = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.butterSoft.withValues(alpha: 0.9),
              AppColors.butterSoft.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(w * 0.1, h * 0.12), radius: w * 0.5),
          );
    canvas.drawCircle(Offset(w * 0.1, h * 0.12), w * 0.5, butter);

    // Mint wash drifting on the right side.
    final mint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.mintSoft.withValues(alpha: 0.8),
              AppColors.mintSoft.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(w * (1.0 - drift * 0.15), h * 0.62),
              radius: w * 0.4,
            ),
          );
    canvas.drawCircle(
      Offset(w * (1.0 - drift * 0.15), h * 0.62),
      w * 0.4,
      mint,
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
