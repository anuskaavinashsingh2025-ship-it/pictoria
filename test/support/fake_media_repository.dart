import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:pictoria/data/media/device_media_repository.dart'
    show classifyDeletion;
import 'package:pictoria/data/media/media_access.dart';
import 'package:pictoria/data/media/media_item.dart';
import 'package:pictoria/data/media/media_repository.dart';
import 'package:pictoria/data/media/platform_info.dart';

/// A pretend device library for tests: no plugin, no real photos.
///
/// Configure what it returns, then inspect the counters to check how the
/// app used it (for example, that it never asked for permission on launch).
class FakeMediaRepository implements MediaRepository {
  FakeMediaRepository({
    this.access = MediaAccess.granted,
    MediaAccess? accessAfterRequest,
    List<MediaItem>? items,
  }) : accessAfterRequest = accessAfterRequest ?? access,
       items = items ?? const [];

  /// What [checkAccess] reports.
  MediaAccess access;

  /// What [requestAccess] reports (and then becomes the new [access]).
  MediaAccess accessAfterRequest;

  /// The whole fake library, newest first.
  List<MediaItem> items;

  /// When set, the next [fetchPage] throws this once.
  Object? nextFetchError;

  /// When set, [fetchPage] waits for this before answering (to test
  /// loading states and stale results).
  Completer<void>? fetchGate;

  int checkCount = 0;
  int requestCount = 0;
  int fetchCount = 0;
  int oldestFirstFetches = 0;
  int openSettingsCount = 0;
  int manageSelectionCount = 0;
  int invalidateCount = 0;
  final fetchedPages = <(MediaTypeFilter, int)>[];

  @override
  Future<MediaAccess> checkAccess() async {
    checkCount++;
    return access;
  }

  @override
  Future<MediaAccess> requestAccess() async {
    requestCount++;
    access = accessAfterRequest;
    return access;
  }

  @override
  Future<List<MediaItem>> fetchPage({
    required MediaTypeFilter type,
    required int page,
    required int pageSize,
    bool oldestFirst = false,
  }) async {
    fetchCount++;
    fetchedPages.add((type, page));
    if (oldestFirst) oldestFirstFetches++;
    final gate = fetchGate;
    if (gate != null) await gate.future;

    final error = nextFetchError;
    if (error != null) {
      nextFetchError = null;
      throw error;
    }

    final matching = items.where(
      (item) => switch (type) {
        MediaTypeFilter.all => true,
        MediaTypeFilter.photos => !item.isVideo,
        MediaTypeFilter.videos => item.isVideo,
      },
    );
    final ordered = oldestFirst ? matching.toList().reversed : matching;
    return ordered.skip(page * pageSize).take(pageSize).toList();
  }

  /// Returns null ("unavailable"), which the tiles show as a placeholder.
  /// That keeps widget tests free of real image decoding.
  @override
  Future<Uint8List?> loadThumbnail(
    MediaItem item, {
    required int width,
    required int height,
  }) async => null;

  /// What [loadVideoFile] returns. The file is never opened: viewer tests
  /// pass a fake player factory.
  File? videoFile = File('fake_video.mp4');
  int videoFileCalls = 0;

  @override
  Future<File?> loadVideoFile(MediaItem item) async {
    videoFileCalls++;
    return videoFile;
  }

  @override
  Future<MediaDetails> loadDetails(MediaItem item) async =>
      const MediaDetails(fileSizeBytes: 2048, mimeType: 'image/heic');

  /// File sizes by id; items not listed are 2 KB. Ids in [unknownSizeIds]
  /// report no size.
  Map<String, int> sizes = {};
  Set<String> unknownSizeIds = {};
  int fileSizeCalls = 0;

  @override
  Future<int?> fileSize(MediaItem item) async {
    fileSizeCalls++;
    if (unknownSizeIds.contains(item.id)) return null;
    return sizes[item.id] ?? 2048;
  }

  @override
  Future<int?> mediaCount() async => access.canReadMedia ? items.length : 0;

  @override
  Future<void> openSettings() async => openSettingsCount++;

  @override
  Future<void> manageLimitedSelection() async => manageSelectionCount++;

  @override
  void invalidate() => invalidateCount++;

  // --- Deletion (simulated: never touches real media) ------------------------

  DeletionMode mode = DeletionMode.recentlyDeleted;

  /// Ids that the fake reports as already gone from the library.
  Set<String> missingIds = {};

  /// How the simulated system prompt answers. Return the ids "deleted".
  /// Default: the user confirms, everything is removed.
  Future<List<String>> Function(List<String> ids)? onDelete;

  /// When set, deleting throws this (a platform failure).
  Object? deleteError;

  int deleteCallCount = 0;
  final deleteRequests = <List<String>>[];

  @override
  Future<DeletionMode> deletionMode() async => mode;

  @override
  Future<Set<String>> findMissing(List<MediaItem> items) async => {
    for (final item in items)
      if (missingIds.contains(item.id)) item.id,
  };

  @override
  Future<DeletionResult> deleteMedia(List<MediaItem> items) async {
    deleteCallCount++;
    final requested = {for (final item in items) item.id};
    if (!access.canReadMedia) {
      return DeletionResult(
        status: DeletionStatus.permissionDenied,
        mode: mode,
        failedIds: requested,
      );
    }
    final missing = await findMissing(items);
    final ids = requested.difference(missing).toList();
    deleteRequests.add(ids);

    var returned = const <String>[];
    Object? error;
    if (ids.isNotEmpty) {
      try {
        if (deleteError != null) throw deleteError!;
        returned = await (onDelete?.call(ids) ?? Future.value(ids));
      } catch (e) {
        error = e;
      }
    }
    // Simulate the library changing.
    this.items = [
      for (final item in this.items)
        if (!returned.contains(item.id) && !missing.contains(item.id)) item,
    ];
    return classifyDeletion(
      mode: mode,
      requestedIds: requested,
      missingIds: missing,
      returnedIds: returned.toSet(),
      error: error,
    );
  }
}

/// Builds [count] fake device items, newest first, one per hour.
List<MediaItem> fakeDeviceItems(
  int count, {
  DateTime? newest,
  bool Function(int index)? isVideo,
}) {
  // Midday today, so up to ~12 items stay in the "Today" section.
  final now = DateTime.now();
  final start = newest ?? DateTime(now.year, now.month, now.day, 12);
  return [
    for (var i = 0; i < count; i++)
      MediaItem(
        id: 'device-$i',
        kind: (isVideo?.call(i) ?? false) ? MediaKind.video : MediaKind.photo,
        createdAt: start.subtract(Duration(hours: i)),
        width: i.isEven ? 4032 : 3024,
        height: i.isEven ? 3024 : 4032,
        duration: (isVideo?.call(i) ?? false)
            ? const Duration(seconds: 15)
            : null,
        title: 'IMG_$i.HEIC',
      ),
  ];
}

/// Reports fixed device storage instead of asking the real OS.
class FakePlatformInfo extends PlatformInfo {
  FakePlatformInfo([this.storage]);

  DeviceStorage? storage;

  @override
  Future<DeviceStorage?> deviceStorage() async => storage;

  @override
  Future<int?> androidSdkInt() async => null;
}
