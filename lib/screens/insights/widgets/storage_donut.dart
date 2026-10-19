import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';

/// One coloured slice of the donut, as a fraction of the whole ring (0–1).
class DonutSlice {
  const DonutSlice({required this.fraction, required this.color});

  final double fraction;
  final Color color;
}

/// A soft pastel donut chart with rounded slice ends and a label in the
/// middle. Slices sweep in once when first shown (instantly with reduced
/// motion). The chart itself is decorative for screen readers; the legend
/// next to it carries the numbers.
class StorageDonut extends StatelessWidget {
  const StorageDonut({
    super.key,
    required this.slices,
    required this.center,
    this.size = 150,
  });

  final List<DonutSlice> slices;
  final Widget center;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppDurations.of(context, const Duration(milliseconds: 900)),
        curve: AppCurves.emphasized,
        builder: (context, progress, child) => CustomPaint(
          painter: _DonutPainter(slices: slices, progress: progress),
          child: child,
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.progress});

  final List<DonutSlice> slices;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.13;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - stroke) / 2,
    );
    Paint paintFor(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Free space / background ring.
    canvas.drawArc(rect, 0, math.pi * 2, false, paintFor(AppColors.chartTrack));

    // A small gap between slices keeps rounded ends from overlapping.
    const gap = 0.06;
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = slice.fraction.clamp(0.0, 1.0) * math.pi * 2 * progress;
      if (sweep <= 0) continue;
      final visible = math.max(sweep - gap, 0.001);
      canvas.drawArc(rect, start, visible, false, paintFor(slice.color));
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.slices != slices;
}
