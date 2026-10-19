import 'package:flutter/material.dart';

import '../../../data/demo_media.dart';
import '../../../data/media/media_filters.dart';
import '../../../data/media/media_item.dart';
import '../../../data/media/media_repository.dart';
import '../../../state/insights_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/doodles.dart';
import '../../deletion/widgets/deletion_widgets.dart';
import '../../onboarding/widgets/photo_collage.dart';
import 'storage_donut.dart';

/// Rounded tinted card used for every Insights section.
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.child,
    this.color = AppColors.ivory,
    this.gradient,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.lg + 2),
  });

  final Widget child;
  final Color color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.lg + 2);
    Widget card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (semanticLabel != null) {
      card = Semantics(
        button: onTap != null,
        label: semanticLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: card,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: radius,
        boxShadow: AppShadows.soft,
      ),
      child: card,
    );
  }
}

// -----------------------------------------------------------------------------
// Storage
// -----------------------------------------------------------------------------

class StorageCard extends StatelessWidget {
  const StorageCard({super.key, required this.insights});

  final InsightsController insights;

  @override
  Widget build(BuildContext context) {
    final storage = insights.storage;
    final stats = insights.stats;
    final status = insights.status;
    final hasLibrary =
        status == InsightsStatus.ready || status == InsightsStatus.scanning;
    final measuring = status == InsightsStatus.scanning;
    final other = insights.everythingElseBytes;

    // Slices are only drawn from real figures.
    final slices = <DonutSlice>[];
    Widget center;
    if (storage != null) {
      final total = storage.totalBytes;
      if (hasLibrary && !measuring && other != null) {
        slices
          ..add(
            DonutSlice(
              fraction: stats.photoBytes / total,
              color: AppColors.primary,
            ),
          )
          ..add(
            DonutSlice(
              fraction: stats.videoBytes / total,
              color: AppColors.videoSlice,
            ),
          )
          ..add(
            DonutSlice(fraction: other / total, color: AppColors.chartOther),
          );
      } else {
        // Breakdown not known (yet): show only what the OS reports as used.
        slices.add(
          DonutSlice(
            fraction: storage.usedFraction,
            color: AppColors.chartOther,
          ),
        );
      }
      center = _CenterLabel(
        value: '${(storage.usedFraction * 100).round()}%',
        caption: 'used',
      );
    } else {
      // No device figures: show the measured library on its own.
      final media = stats.mediaBytes;
      if (hasLibrary && media > 0) {
        slices
          ..add(
            DonutSlice(
              fraction: stats.photoBytes / media,
              color: AppColors.primary,
            ),
          )
          ..add(
            DonutSlice(
              fraction: stats.videoBytes / media,
              color: AppColors.videoSlice,
            ),
          );
      }
      center = _CenterLabel(
        value: hasLibrary ? formatFileSize(media) : '—',
        caption: 'library',
        compact: true,
      );
    }

    return InsightCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 300;
          final donut = ExcludeSemantics(
            child: StorageDonut(
              // Rebuild (and re-animate) when the breakdown appears.
              key: ValueKey('${slices.length}-${insights.status}'),
              slices: slices,
              center: center,
              size: narrow ? 128 : 150,
            ),
          );
          final legend = _Legend(insights: insights);
          if (narrow) {
            return Column(
              children: [
                donut,
                const SizedBox(height: AppSpacing.lg),
                legend,
              ],
            );
          }
          return Row(
            children: [
              donut,
              const SizedBox(width: AppSpacing.xl),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }
}

class _CenterLabel extends StatelessWidget {
  const _CenterLabel({
    required this.value,
    required this.caption,
    this.compact = false,
  });

  final String value;
  final String caption;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          child: Text(
            value,
            style: AppText.sectionTitle.copyWith(fontSize: compact ? 20 : 30),
          ),
        ),
        Text(caption, style: AppText.caption),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.insights});

  final InsightsController insights;

  @override
  Widget build(BuildContext context) {
    final storage = insights.storage;
    final stats = insights.stats;
    final status = insights.status;
    final scanning = status == InsightsStatus.scanning;
    final measured = status == InsightsStatus.ready;
    final other = insights.everythingElseBytes;

    String measuredValue(int bytes) =>
        measured ? formatFileSize(bytes) : (scanning ? '…' : '—');

    final rows = <Widget>[];
    if (status == InsightsStatus.ready || scanning) {
      rows
        ..add(
          _LegendRow(
            color: AppColors.primary,
            label: 'Photos',
            value: measuredValue(stats.photoBytes),
          ),
        )
        ..add(
          _LegendRow(
            color: AppColors.videoSlice,
            label: 'Videos',
            value: measuredValue(stats.videoBytes),
          ),
        );
      if (storage != null) {
        rows.add(
          _LegendRow(
            color: AppColors.chartOther,
            label: 'Other',
            value: other == null
                ? (scanning ? '…' : '—')
                : formatFileSize(other),
          ),
        );
      }
    } else if (storage != null) {
      rows.add(
        _LegendRow(
          color: AppColors.chartOther,
          label: 'Used',
          value: formatFileSize(storage.usedBytes),
        ),
      );
    }
    if (storage != null) {
      rows.add(
        _LegendRow(
          color: AppColors.chartTrack,
          label: 'Free',
          value: formatFileSize(storage.availableBytes),
        ),
      );
    }

    String? note;
    if (scanning) {
      final expected = insights.expectedCount;
      note = expected == null
          ? 'Measuring ${insights.scannedCount} items…'
          : 'Measuring ${insights.scannedCount} of $expected items…';
    } else if (measured && stats.unknownSizeCount > 0) {
      note = '${stats.unknownSizeCount} items had no readable size.';
    } else if (storage == null && insights.storageLoaded) {
      note = 'Device storage isn’t available, so this shows your library only.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (storage != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatFileSize(storage.totalBytes),
                  style: AppText.sectionTitle.copyWith(fontSize: 20),
                ),
                TextSpan(text: '  total', style: AppText.body),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        ...rows,
        if (note != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: scanning,
            child: Text(note, style: AppText.caption),
          ),
        ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Its own node, so screen readers announce each row separately.
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: color == AppColors.chartTrack
                    ? Border.all(color: AppColors.chartOther)
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(color: AppColors.ink),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(value, style: AppText.label),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Reclaim / Duplicates / Large videos
// -----------------------------------------------------------------------------

class ReclaimCard extends StatelessWidget {
  const ReclaimCard({
    super.key,
    required this.bytes,
    required this.videoCount,
    required this.onTap,
  });

  final int bytes;
  final int videoCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = 'Reclaim up to ${formatFileSize(bytes)}';
    final subtitle =
        'from $videoCount large ${videoCount == 1 ? 'video' : 'videos'} '
        '(estimate)';
    return InsightCard(
      gradient: const LinearGradient(
        colors: [AppColors.butterSoft, AppColors.lavenderSoft],
      ),
      onTap: onTap,
      semanticLabel: '$title, $subtitle',
      child: Row(
        children: [
          const Doodle(
            kind: DoodleKind.sparkle,
            color: AppColors.butter,
            size: 34,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.label.copyWith(fontSize: 17)),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}

/// A row card with a small photo stack, title, subtitle and chevron.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.thumbnails,
    this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final Color tint;
  final List<ImageProvider> thumbnails;
  final VoidCallback? onTap;
  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    return InsightCard(
      color: tint,
      onTap: onTap,
      semanticLabel: '$title, $subtitle',
      child: Row(
        children: [
          _ThumbStack(images: thumbnails, badge: badge),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.label.copyWith(fontSize: 17)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.body.copyWith(fontSize: 14)),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
        ],
      ),
    );
  }
}

class _ThumbStack extends StatelessWidget {
  const _ThumbStack({required this.images, this.badge});

  final List<ImageProvider> images;
  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    Widget tile(ImageProvider? image, double angle) => Transform.rotate(
      angle: angle,
      child: Container(
        width: 62,
        height: 62,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(AppRadii.sm + 2),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.sm - 1),
          child: image == null
              ? const ColoredBox(color: AppColors.sand)
              : Image(
                  image: image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: AppColors.sand),
                ),
        ),
      ),
    );

    if (images.isEmpty) {
      // No real photos to show: a soft icon tile, never placeholder "photos".
      return ExcludeSemantics(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.ivory.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Icon(badge ?? Icons.photo_outlined, color: AppColors.inkMuted),
        ),
      );
    }

    return ExcludeSemantics(
      child: SizedBox(
        width: 80,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (images.length > 1)
              Positioned(left: 0, child: tile(images[1], -0.12)),
            Positioned(
              right: 2,
              child: tile(images.isEmpty ? null : images.first, 0.06),
            ),
            if (badge != null)
              Positioned(
                right: 8,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.ivory,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(badge, size: 14, color: AppColors.ink),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Deletion summary
// -----------------------------------------------------------------------------

class DeletionSummaryCard extends StatelessWidget {
  const DeletionSummaryCard({
    super.key,
    required this.items,
    required this.knownBytes,
    required this.unknownCount,
    required this.mode,
    required this.imageFor,
    required this.onContinue,
    required this.onReview,
  });

  final List<MediaItem> items;
  final int knownBytes;
  final int unknownCount;
  final DeletionMode? mode;
  final ImageProvider Function(MediaItem item) imageFor;
  final VoidCallback? onContinue;
  final VoidCallback onReview;

  String get _explanation {
    final one = items.length == 1;
    final these = one ? 'This item' : 'These items';
    final it = one ? 'it leaves' : 'they leave';
    return switch (mode) {
      DeletionMode.recentlyDeleted =>
        '$these will move to Recently Deleted after you confirm. Space is '
            'freed once $it it (after 30 days).',
      DeletionMode.trash =>
        '$these will be moved to your device’s trash after confirmation. '
            'Space is freed once the trash is emptied.',
      DeletionMode.permanent =>
        '$these will be permanently deleted after confirmation.',
      DeletionMode.unsupported =>
        'Demo photos are part of the app and can’t be deleted.',
      null => 'Checking how your device handles deletion…',
    };
  }

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final shown = items.take(3).toList();
    final extra = count - shown.length;
    final size = describeSize(knownBytes, unknownCount);

    return InsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final item in shown) _SummaryThumb(image: imageFor(item)),
                if (extra > 0)
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.lavender,
                      borderRadius: BorderRadius.circular(AppRadii.sm + 2),
                    ),
                    child: Text(
                      '+$extra',
                      style: AppText.label.copyWith(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              '$count ${count == 1 ? 'item' : 'items'} selected',
              style: AppText.sectionTitle,
            ),
          ),
          Text(
            size[0].toUpperCase() + size.substring(1),
            style: AppText.sectionTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_explanation, style: AppText.caption),
          const SizedBox(height: AppSpacing.lg),
          DestructiveButton(label: 'Continue to delete', onPressed: onContinue),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onReview,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.sand, width: 1.5),
                minimumSize: const Size(0, 52),
                shape: const StadiumBorder(),
                textStyle: AppText.label.copyWith(fontSize: 16),
              ),
              child: const Text('Review items'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryThumb extends StatelessWidget {
  const _SummaryThumb({required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.sm + 2),
          child: SizedBox.square(
            dimension: 64,
            child: Image(
              image: image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.sand),
            ),
          ),
        ),
        const Positioned(
          right: 4,
          bottom: 4,
          child: CircleAvatar(
            radius: 9,
            backgroundColor: AppColors.ivory,
            child: Icon(
              Icons.check_rounded,
              size: 12,
              color: AppColors.deleteInk,
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// "More space for what matters" illustration
// -----------------------------------------------------------------------------

class MoreSpaceCard extends StatelessWidget {
  const MoreSpaceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'More space for what matters.',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg + 2),
        child: Container(
          height: 230,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.lavenderSoft, AppColors.peachSoft],
            ),
          ),
          child: Stack(
            children: [
              // Soft blobs.
              Positioned(
                right: -40,
                top: -30,
                child: _Blob(
                  size: 170,
                  color: AppColors.peach.withValues(alpha: 0.5),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -50,
                child: _Blob(
                  size: 160,
                  color: AppColors.lavender.withValues(alpha: 0.6),
                ),
              ),
              Positioned(
                right: 10,
                bottom: -30,
                child: _Blob(size: 90, color: AppColors.mintSoft),
              ),
              // Illustration only: bundled sample photos, not user data.
              Positioned.fill(
                left: 120,
                child: PhotoCollage(
                  cards: [
                    CollageCardSpec(
                      item: demoById('tabby_cat_window'),
                      alignment: const Alignment(-1, 0.9),
                      widthFactor: 0.42,
                      aspectRatio: 0.85,
                      angle: -0.12,
                    ),
                    CollageCardSpec(
                      item: demoById('maldives_aerial'),
                      alignment: const Alignment(0.9, -0.6),
                      widthFactor: 0.42,
                      aspectRatio: 0.72,
                      angle: 0.08,
                    ),
                    CollageCardSpec(
                      item: demoById('pink_tulips'),
                      alignment: const Alignment(0, 0.2),
                      widthFactor: 0.44,
                      aspectRatio: 0.74,
                      angle: -0.04,
                      badge: Icons.favorite_rounded,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.xl,
                top: AppSpacing.xl,
                child: Transform.rotate(
                  angle: -0.1,
                  child: Text(
                    'More space\nfor what\nmatters.',
                    textScaler: TextScaler.noScaling,
                    style: AppText.display.copyWith(fontSize: 26, height: 1.05),
                  ),
                ),
              ),
              const Positioned(
                left: 20,
                bottom: 22,
                child: Doodle(
                  kind: DoodleKind.squiggle,
                  color: AppColors.ink,
                  size: 40,
                ),
              ),
              const Positioned(
                left: 150,
                top: 20,
                child: Doodle(
                  kind: DoodleKind.heart,
                  color: AppColors.rose,
                  size: 22,
                ),
              ),
              const Positioned(
                left: 12,
                top: 120,
                child: Doodle(
                  kind: DoodleKind.heart,
                  color: AppColors.rose,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
