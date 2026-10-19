import 'package:flutter/material.dart';

import '../../data/media/media_filters.dart';
import '../../state/insights_controller.dart';
import '../../state/review_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../deletion/deletion_queue_screen.dart';
import '../deletion/widgets/deletion_widgets.dart';
import '../gallery/widgets/gallery_states.dart';
import '../review/widgets/review_buttons.dart';

/// Lists videos over the size threshold, biggest first. Marking a video only
/// adds it to the deletion queue; nothing is deleted from here.
class LargeVideosScreen extends StatelessWidget {
  const LargeVideosScreen({
    super.key,
    required this.insights,
    required this.review,
  });

  final InsightsController insights;
  final ReviewController review;

  @override
  Widget build(BuildContext context) {
    final pixelWidth = (64 * MediaQuery.devicePixelRatioOf(context)).round();
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([insights, review]),
          builder: (context, _) {
            final videos = insights.stats.largeVideos
                .where((video) => insights.sizeOf(video.item) != null)
                .toList();
            final marked = review.markedCount;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.md,
                    AppSpacing.screen,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Large videos',
                            style: AppText.display.copyWith(fontSize: 26),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screen,
                  ),
                  child: Text(
                    'Videos over '
                    '${formatFileSize(insights.largeVideoThresholdBytes)}, '
                    'biggest first. Marking one adds it to your deletion '
                    'queue — nothing is deleted until you confirm.',
                    style: AppText.caption,
                  ),
                ),
                Expanded(
                  child: videos.isEmpty
                      ? const GalleryMessage(
                          title: 'No large videos',
                          message: 'Nothing here takes up unusual space.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.screen),
                          itemCount: videos.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final video = videos[index];
                            final item = video.item;
                            final isMarked = review.isMarked(item);
                            final created = item.createdAt;
                            final when = created == null
                                ? 'Undated'
                                : dayLabel(created, DateTime.now());
                            final length = item.duration == null
                                ? ''
                                : ' · ${formatDuration(item.duration!)}';
                            return _VideoRow(
                              image: review.gallery.thumbnailFor(
                                item,
                                pixelWidth: pixelWidth,
                              ),
                              title: formatFileSize(video.bytes),
                              subtitle: '$when$length',
                              marked: isMarked,
                              onToggle: () => isMarked
                                  ? review.restoreToReview(item)
                                  : review.markItemForDeletion(
                                      item,
                                      sizeBytes: video.bytes,
                                    ),
                            );
                          },
                        ),
                ),
                if (marked > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      0,
                      AppSpacing.screen,
                      AppSpacing.lg,
                    ),
                    child: DestructiveButton(
                      icon: Icons.checklist_rounded,
                      label:
                          'Review $marked marked '
                          '${marked == 1 ? 'item' : 'items'}',
                      onPressed: () =>
                          DeletionQueueScreen.open(context, review),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  const _VideoRow({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.marked,
    required this.onToggle,
  });

  final ImageProvider image;
  final String title;
  final String subtitle;
  final bool marked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      toggled: marked,
      label: 'Video, $title, $subtitle',
      hint: marked
          ? 'Marked for deletion. Double tap to unmark.'
          : 'Double tap to mark for deletion.',
      onTap: onToggle,
      excludeSemantics: true,
      child: Material(
        color: AppColors.ivory,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: SizedBox.square(
                    dimension: 64,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(
                          image: image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: AppColors.sand),
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.label.copyWith(fontSize: 16)),
                      Text(subtitle, style: AppText.caption),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: AppDurations.of(context, AppDurations.fast),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: marked ? AppColors.deleteInk : AppColors.peachSoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    marked ? 'Marked' : 'Mark',
                    style: AppText.label.copyWith(
                      color: marked ? Colors.white : AppColors.deleteInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
