import 'package:flutter/material.dart';

import '../../data/media/media_filters.dart';
import '../../data/media/media_item.dart';
import '../../data/media/media_repository.dart';
import '../../state/insights_controller.dart';
import '../../state/review_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/doodles.dart';
import '../deletion/deletion_queue_screen.dart';
import '../gallery/widgets/library_access_banner.dart';
import '../gallery/widgets/library_source_sheet.dart';
import '../review/widgets/review_buttons.dart';
import 'large_videos_screen.dart';
import 'widgets/insight_cards.dart';

/// The Insights tab: device storage, what the photo library uses, large
/// videos to reclaim, and a summary of items waiting to be deleted.
///
/// Honesty rules: totals come from the OS, library sizes are measured file
/// by file, duplicates are not guessed, and "reclaim" is always an estimate.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({
    super.key,
    required this.insights,
    required this.review,
  });

  final InsightsController insights;
  final ReviewController review;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Future<DeletionMode>? _mode;
  bool? _modeForDemo;

  InsightsController get _insights => widget.insights;
  ReviewController get _review => widget.review;

  /// Deletion behaviour for the current library, looked up once per source.
  Future<DeletionMode> _deletionMode() {
    final demo = _review.gallery.isShowingDemo;
    if (_mode == null || _modeForDemo != demo) {
      _modeForDemo = demo;
      _mode = _review.gallery.deletionModeFor(demo: demo);
    }
    return _mode!;
  }

  ImageProvider _thumb(MediaItem item, {double width = 64}) =>
      _review.gallery.thumbnailFor(
        item,
        pixelWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
      );

  void _openLargeVideos() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            LargeVideosScreen(insights: _insights, review: _review),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cream,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([_insights, _review]),
          builder: (context, _) => RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _insights.scan,
            child: Center(
              child: ConstrainedBox(
                // Comfortable reading width on tablets.
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.md,
                    AppSpacing.screen,
                    150, // room for the floating nav bar
                  ),
                  children: _sections(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _sections() {
    const gap = SizedBox(height: AppSpacing.lg);
    final status = _insights.status;
    final stats = _insights.stats;

    return [
      _Header(
        onSettings: () => showLibrarySourceSheet(context, _review.gallery),
      ),
      LibraryAccessBanner(controller: _review.gallery),
      gap,
      if (status == InsightsStatus.error)
        _ErrorCard(onRetry: _insights.scan)
      else
        StorageCard(insights: _insights),
      gap,
      ..._reclaimSection(status, stats),
      FeatureCard(
        title: 'Duplicates',
        subtitle:
            'Not available yet — Pictora doesn’t detect duplicates '
            'reliably, so it won’t guess.',
        tint: AppColors.mintSoft,
        thumbnails: const [],
        badge: Icons.copy_all_rounded,
      ),
      gap,
      _largeVideosCard(status, stats),
      gap,
      ..._deletionSummary(),
      const MoreSpaceCard(),
      gap,
      Text(
        'Photo and video sizes are measured from the items Pictora can '
        'access. Total and free space come from your device. “Other” is '
        'everything else: apps, system data and any media Pictora can’t '
        'see. Deleted items '
        'stay in Recently Deleted or the trash for about 30 days, so space '
        'is freed later.',
        style: AppText.caption,
      ),
    ];
  }

  List<Widget> _reclaimSection(InsightsStatus status, LibraryStats stats) {
    if (status == InsightsStatus.scanning) {
      return const [
        _InfoLine(text: 'Looking for space you can reclaim…', busy: true),
        SizedBox(height: AppSpacing.lg),
      ];
    }
    if (status != InsightsStatus.ready || stats.largeVideos.isEmpty) {
      return const [];
    }
    return [
      ReclaimCard(
        bytes: stats.largeVideoBytes,
        videoCount: stats.largeVideos.length,
        onTap: _openLargeVideos,
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  Widget _largeVideosCard(InsightsStatus status, LibraryStats stats) {
    final videos = stats.largeVideos;
    final threshold = formatFileSize(_insights.largeVideoThresholdBytes);
    final String subtitle;
    VoidCallback? onTap;
    switch (status) {
      case InsightsStatus.ready:
        subtitle = videos.isEmpty
            ? 'No videos over $threshold'
            : '${videos.length} ${videos.length == 1 ? 'file' : 'files'} · '
                  '${formatFileSize(stats.largeVideoBytes)}';
        if (videos.isNotEmpty) onTap = _openLargeVideos;
      case InsightsStatus.scanning:
        subtitle = 'Measuring your videos…';
      case InsightsStatus.demo:
      case InsightsStatus.noAccess:
        subtitle = 'Connect your photo library to find them';
      case InsightsStatus.error:
        subtitle = 'Couldn’t measure your videos';
      case InsightsStatus.idle:
        subtitle = 'Checking…';
    }
    return FeatureCard(
      title: 'Large videos',
      subtitle: subtitle,
      tint: AppColors.butterSoft,
      thumbnails: [
        for (final video in videos.take(2)) _thumb(video.item, width: 62),
      ],
      badge: Icons.play_arrow_rounded,
      onTap: onTap,
    );
  }

  List<Widget> _deletionSummary() {
    final records = _review.markedRecords;
    if (records.isEmpty) return const [];

    var known = 0;
    var unknown = 0;
    for (final record in records) {
      final bytes = record.fileSizeBytes ?? _insights.sizeOf(record.item);
      if (bytes == null) {
        unknown++;
      } else {
        known += bytes;
      }
    }

    return [
      FutureBuilder<DeletionMode>(
        future: _deletionMode(),
        builder: (context, snapshot) {
          final mode = snapshot.data;
          final canDelete = mode != null && mode != DeletionMode.unsupported;
          return DeletionSummaryCard(
            items: [for (final record in records) record.item],
            knownBytes: known,
            unknownCount: unknown,
            mode: mode,
            imageFor: _thumb,
            onContinue: canDelete
                ? () => DeletionQueueScreen.open(
                    context,
                    _review,
                    autoConfirm: true,
                  )
                : null,
            onReview: () => DeletionQueueScreen.open(context, _review),
          );
        },
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Semantics(
            header: true,
            child: Text(
              'Insights',
              style: AppText.display.copyWith(fontSize: 34),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Doodle(
            kind: DoodleKind.sparkle,
            color: AppColors.butter,
            size: 24,
          ),
          const Spacer(),
          CircleIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Library settings',
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.text, this.busy = false});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          if (busy) ...[
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: Text(text, style: AppText.caption)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return InsightCard(
      color: AppColors.peachSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Couldn’t measure your library', style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Something went wrong while reading file sizes. Nothing was '
            'changed.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: const StadiumBorder(),
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
