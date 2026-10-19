import 'package:flutter/material.dart';

import '../../../data/demo_media.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/doodles.dart';

/// Where one tilted photo card sits inside the collage.
class CollageCardSpec {
  const CollageCardSpec({
    required this.item,
    required this.alignment,
    required this.widthFactor,
    required this.aspectRatio,
    required this.angle,
    this.badge,
  });

  final DemoPhoto item;

  /// Position inside the collage box: (-1, -1) is top-left, (1, 1) bottom-right.
  final Alignment alignment;

  /// Card width as a fraction of the collage width.
  final double widthFactor;

  /// Width / height of the card frame (the photo is cropped to fit).
  final double aspectRatio;

  /// Tilt in radians (small values like 0.08 look best).
  final double angle;

  /// Optional little icon badge in the card's corner.
  final IconData? badge;
}

/// A decorative doodle placed inside the collage.
class CollageDoodleSpec {
  const CollageDoodleSpec({
    required this.kind,
    required this.color,
    required this.alignment,
    this.size = 28,
    this.angle = 0,
    this.onTop = false,
  });

  final DoodleKind kind;
  final Color color;
  final Alignment alignment;
  final double size;
  final double angle;

  /// Paint above the photo cards (overlapping an edge) instead of behind.
  final bool onTop;
}

/// Overlapping, tilted photo cards with playful doodles around them.
///
/// Cards are listed back-to-front: later cards are painted on top.
class PhotoCollage extends StatelessWidget {
  const PhotoCollage({super.key, required this.cards, this.doodles = const []});

  final List<CollageCardSpec> cards;
  final List<CollageDoodleSpec> doodles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        // Keep the collage proportionate on wide screens (tablets, desktop).
        final baseWidth = width.clamp(0.0, height * 0.95);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final doodle in doodles)
              if (!doodle.onTop) _doodle(doodle),
            for (final card in cards)
              Align(
                alignment: card.alignment,
                child: _TiltedPhotoCard(
                  spec: card,
                  // Cap the height so tall cards never overflow the box.
                  width: (baseWidth * card.widthFactor).clamp(
                    0.0,
                    height * 0.62 * card.aspectRatio,
                  ),
                ),
              ),
            for (final doodle in doodles)
              if (doodle.onTop) _doodle(doodle),
          ],
        );
      },
    );
  }

  Widget _doodle(CollageDoodleSpec doodle) {
    return Align(
      alignment: doodle.alignment,
      child: Doodle(
        kind: doodle.kind,
        color: doodle.color,
        size: doodle.size,
        angle: doodle.angle,
      ),
    );
  }
}

class _TiltedPhotoCard extends StatelessWidget {
  const _TiltedPhotoCard({required this.spec, required this.width});

  final CollageCardSpec spec;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width / spec.aspectRatio;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    const border = 6.0;

    return Transform.rotate(
      angle: spec.angle,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(border),
        decoration: BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: AppShadows.card,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.lg - border),
              child: Image.asset(
                spec.item.assetPath,
                fit: BoxFit.cover,
                // Decode at display size only, not the full-resolution file.
                cacheWidth: (width * pixelRatio).round(),
                semanticLabel: spec.item.title,
              ),
            ),
            if (spec.badge != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.ivory,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(spec.badge, size: 16, color: AppColors.rose),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
