import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/media/media_filters.dart';
import '../../data/media/media_item.dart';
import '../../data/media/media_repository.dart';
import '../../state/gallery_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'widgets/video_stage.dart';

/// A minimal full-screen viewer with pinch-to-zoom and basic details.
///
/// It shows a screen-sized thumbnail rather than the original file, which
/// keeps memory low; full-resolution viewing can come later.
/// The [Hero] tag matches the grid tile, so the photo appears to fly from the
/// grid into the viewer. Videos play in a [VideoStage] instead.
class MediaViewerScreen extends StatelessWidget {
  const MediaViewerScreen({
    super.key,
    required this.item,
    required this.controller,
    this.createVideoController = VideoPlayerController.file,
  });

  final MediaItem item;
  final GalleryController controller;

  /// How video players are made (tests pass a fake).
  final VideoControllerFactory createVideoController;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final picture = Center(
      child: Hero(
        tag: item.id,
        child: Image(
          image: controller.thumbnailFor(
            item,
            pixelWidth: (size.width * pixelRatio).round(),
          ),
          fit: BoxFit.contain,
          semanticLabel: item.accessibilityLabel,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.broken_image_outlined,
            color: AppColors.lavender,
            size: 48,
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: const CloseButton(),
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Expanded(
            child: item.isVideo
                ? VideoStage(
                    key: ValueKey(item.id),
                    item: item,
                    poster: picture,
                    loadFile: () => controller.videoFileFor(item),
                    createController: createVideoController,
                  )
                : InteractiveViewer(maxScale: 4, child: picture),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: _Details(item: item, controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.item, required this.controller});

  final MediaItem item;
  final GalleryController controller;

  @override
  Widget build(BuildContext context) {
    final created = item.createdAt;
    final when = created == null
        ? 'Undated'
        : dayLabel(created, DateTime.now());
    final infoStyle = AppText.body.copyWith(color: AppColors.lavender);

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title ?? (item.isVideo ? 'Video' : 'Photo'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.display.copyWith(fontSize: 26, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              when,
              if (item.width > 0) '${item.width} × ${item.height}',
              if (item.duration != null) formatDuration(item.duration!),
            ].join(' · '),
            style: infoStyle,
          ),
          // File size and type are fetched only now, for this one item.
          FutureBuilder<MediaDetails>(
            future: controller.detailsFor(item),
            builder: (context, snapshot) {
              final details = snapshot.data;
              final parts = [
                if (details?.mimeType != null) details!.mimeType!,
                if (details?.fileSizeBytes != null)
                  formatFileSize(details!.fileSizeBytes!),
                if (item.isDeviceFavorite) '♥ Favorite in Photos',
              ];
              if (parts.isEmpty) return const SizedBox(height: 22);
              return Text(parts.join(' · '), style: infoStyle);
            },
          ),
        ],
      ),
    );
  }
}
