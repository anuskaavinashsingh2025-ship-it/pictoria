import 'dart:io';

import 'package:flutter/services.dart';

import '../demo_media.dart';
import 'media_access.dart';
import 'media_filters.dart';
import 'media_item.dart';
import 'media_repository.dart';

/// Serves the bundled demo photos through the same interface as the device
/// library, so the Gallery code path is identical in demo mode.
///
/// Demo thumbnails are drawn straight from app assets (see
/// GalleryController.thumbnailFor), so [loadThumbnail] is never needed.
class DemoMediaRepository implements MediaRepository {
  DemoMediaRepository({DateTime Function()? clock, AssetBundle? bundle})
    : _clock = clock ?? DateTime.now,
      _bundle = bundle ?? rootBundle;

  final DateTime Function() _clock;
  final AssetBundle _bundle;

  /// Ids of demo photos that start out as Pictora favorites.
  static Set<String> get initialFavoriteIds => {
    for (final photo in demoPhotos)
      if (photo.initiallyFavorite) photo.id,
  };

  @override
  Future<MediaAccess> checkAccess() async => MediaAccess.granted;

  @override
  Future<MediaAccess> requestAccess() async => MediaAccess.granted;

  @override
  Future<List<MediaItem>> fetchPage({
    required MediaTypeFilter type,
    required int page,
    required int pageSize,
    bool oldestFirst = false,
  }) async {
    final now = _clock();
    final all =
        sortNewestFirst(demoPhotos.map((photo) => photo.toMediaItem(now)))
            .where(
              (item) => switch (type) {
                MediaTypeFilter.all => true,
                MediaTypeFilter.photos => !item.isVideo,
                MediaTypeFilter.videos => item.isVideo,
              },
            );
    final ordered = oldestFirst ? all.toList().reversed : all;
    return ordered.skip(page * pageSize).take(pageSize).toList();
  }

  @override
  Future<Uint8List?> loadThumbnail(
    MediaItem item, {
    required int width,
    required int height,
  }) async => null;

  /// Demo "videos" are bundled stills, so there is nothing to play.
  @override
  Future<File?> loadVideoFile(MediaItem item) async => null;

  @override
  Future<MediaDetails> loadDetails(MediaItem item) async {
    try {
      final data = await _bundle.load(item.assetPath!);
      return MediaDetails(
        fileSizeBytes: data.lengthInBytes,
        mimeType: item.mimeType,
      );
    } catch (_) {
      return MediaDetails(mimeType: item.mimeType);
    }
  }

  @override
  Future<int?> fileSize(MediaItem item) async =>
      (await loadDetails(item)).fileSizeBytes;

  @override
  Future<int?> mediaCount() async => demoPhotos.length;

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> manageLimitedSelection() async {}

  @override
  void invalidate() {}

  /// Demo photos are part of the app, so they can never be deleted.
  @override
  Future<DeletionMode> deletionMode() async => DeletionMode.unsupported;

  @override
  Future<Set<String>> findMissing(List<MediaItem> items) async => const {};

  @override
  Future<DeletionResult> deleteMedia(List<MediaItem> items) async =>
      DeletionResult(
        status: DeletionStatus.failed,
        mode: DeletionMode.unsupported,
        failedIds: {for (final item in items) item.id},
        message: 'Demo photos cannot be deleted',
      );
}
