import 'package:flutter/material.dart';

import '../../../data/media/media_filters.dart';
import '../../../data/media/media_item.dart';
import '../../../theme/app_tokens.dart';

/// One rounded photo in the gallery grid, with a favorite toggle and, for
/// videos, a duration badge.
class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.image,
    required this.width,
    required this.height,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  final MediaItem item;

  /// The thumbnail to show (from the device library or a bundled asset).
  final ImageProvider image;

  final double width;
  final double height;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            button: true,
            label:
                '${item.accessibilityLabel}${isFavorite ? ', favorite' : ''}',
            onTap: onTap,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onTap,
              child: Hero(
                tag: item.id,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: ColoredBox(
                    color: AppColors.sand,
                    child: Image(
                      // A small thumbnail sized for this tile, never the
                      // full-resolution original.
                      image: image,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      // Gently fade photos in as they finish decoding.
                      frameBuilder: (context, child, frame, wasSyncLoaded) {
                        if (wasSyncLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: AppDurations.of(context, AppDurations.slow),
                          curve: AppCurves.standard,
                          child: child,
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.inkMuted,
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (item.isVideo && item.duration != null)
            Positioned(
              left: 8,
              bottom: 8,
              child: _VideoBadge(duration: item.duration!),
            ),
          Positioned(
            right: 4,
            bottom: 4,
            child: _FavoriteButton(
              isFavorite: isFavorite,
              onPressed: onFavoriteToggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 2),
            Text(
              formatDuration(duration),
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onPressed});

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // The visible circle is small, but the tap target is a comfortable 40×40.
    return Semantics(
      button: true,
      toggled: isFavorite,
      label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedContainer(
              duration: AppDurations.of(context, AppDurations.fast),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isFavorite
                    ? AppColors.ivory
                    : Colors.white.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: AnimatedSwitcher(
                duration: AppDurations.of(context, AppDurations.fast),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: ValueKey(isFavorite),
                  size: 16,
                  color: isFavorite ? AppColors.rose : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
