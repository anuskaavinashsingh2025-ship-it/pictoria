import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import 'media_access.dart';
import 'media_item.dart';
import 'media_repository.dart';
import 'platform_info.dart';

/// Reads photos and videos from the device library using photo_manager.
///
/// This is the ONLY file that talks to the plugin. Everything it returns is
/// converted into Pictora's own [MediaItem] / [MediaAccess] types.
class DeviceMediaRepository implements MediaRepository {
  DeviceMediaRepository({TargetPlatform? platform, PlatformInfo? info})
    : _platform = platform ?? defaultTargetPlatform,
      _info = info ?? const PlatformInfo();

  final TargetPlatform _platform;
  final PlatformInfo _info;
  DeletionMode? _deletionMode;

  /// The "Recents / All photos" album for each type, fetched once and reused
  /// until [invalidate] is called.
  final _rootAlbums = <(MediaTypeFilter, bool), Future<AssetPathEntity?>>{};

  /// Assets we've already fetched, so thumbnail and details requests don't
  /// have to look them up again by id.
  final _assets = <String, AssetEntity>{};

  /// How many times the user has said no during this app session.
  int _deniedRequests = 0;

  /// Photos + videos, without precise location (we don't need it).
  static const _permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  @override
  Future<MediaAccess> checkAccess() async {
    final state = await PhotoManager.getPermissionState(
      requestOption: _permissionOption,
    );
    return mapPermissionState(
      state,
      platform: _platform,
      deniedRequests: _deniedRequests,
    );
  }

  @override
  Future<MediaAccess> requestAccess() async {
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: _permissionOption,
    );
    if (state == PermissionState.denied) _deniedRequests++;
    return mapPermissionState(
      state,
      platform: _platform,
      deniedRequests: _deniedRequests,
    );
  }

  @override
  Future<List<MediaItem>> fetchPage({
    required MediaTypeFilter type,
    required int page,
    required int pageSize,
    bool oldestFirst = false,
  }) async {
    final key = (type, oldestFirst);
    try {
      final album = await _rootAlbums.putIfAbsent(
        key,
        () => _loadRoot(type, oldestFirst: oldestFirst),
      );
      if (album == null) return const []; // empty library
      final assets = await album.getAssetListPaged(page: page, size: pageSize);
      final items = <MediaItem>[];
      for (final asset in assets) {
        final item = mediaItemFromAsset(asset);
        if (item == null) continue; // audio or unknown types
        _assets[asset.id] = asset;
        items.add(item);
      }
      return items;
    } catch (error) {
      // Don't cache a failed album lookup; the next retry should try again.
      _rootAlbums.remove(key);
      throw MediaLoadException(
        "Couldn't read your photo library. Please try again.",
        error,
      );
    }
  }

  Future<AssetPathEntity?> _loadRoot(
    MediaTypeFilter type, {
    bool oldestFirst = false,
  }) async {
    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true, // just the single "all media" album
      type: requestTypeFor(type),
      filterOption: FilterOptionGroup(
        orders: [
          OrderOption(type: OrderOptionType.createDate, asc: oldestFirst),
        ],
      ),
    );
    return albums.isEmpty ? null : albums.first;
  }

  @override
  Future<Uint8List?> loadThumbnail(
    MediaItem item, {
    required int width,
    required int height,
  }) async {
    try {
      final asset = await _assetFor(item.id);
      if (asset == null) return null; // deleted or no longer shared
      return await asset.thumbnailDataWithSize(
        ThumbnailSize(width, height),
        quality: 85,
      );
    } catch (error) {
      debugPrint('Thumbnail failed for ${item.id}: $error');
      return null;
    }
  }

  @override
  Future<VideoSource?> loadVideo(MediaItem item) async {
    try {
      final asset = await _assetFor(item.id);
      if (asset == null || asset.type != AssetType.video) return null;
      final file = await asset.file;
      return file == null ? null : FileVideoSource(file);
    } catch (error) {
      debugPrint('Video file failed for ${item.id}: $error');
      return null;
    }
  }

  @override
  Future<MediaDetails> loadDetails(MediaItem item) async {
    final asset = await _assetFor(item.id);
    if (asset == null) return const MediaDetails();

    int? size;
    String? mime = asset.mimeType;
    try {
      final bytes = await asset.fileSize;
      size = bytes > 0 ? bytes : null;
    } catch (error) {
      debugPrint('File size failed for ${item.id}: $error');
    }
    try {
      mime ??= await asset.mimeTypeAsync;
    } catch (error) {
      debugPrint('MIME type failed for ${item.id}: $error');
    }
    return MediaDetails(fileSizeBytes: size, mimeType: mime);
  }

  @override
  Future<int?> fileSize(MediaItem item) async {
    try {
      final asset = await _assetFor(item.id);
      if (asset == null) return null;
      final bytes = await asset.fileSize;
      return bytes > 0 ? bytes : null;
    } catch (error) {
      debugPrint('File size failed for ${item.id}: $error');
      return null;
    }
  }

  @override
  Future<int?> mediaCount() async {
    try {
      const key = (MediaTypeFilter.all, false);
      final album = await _rootAlbums.putIfAbsent(
        key,
        () => _loadRoot(MediaTypeFilter.all),
      );
      return album == null ? 0 : await album.assetCountAsync;
    } catch (error) {
      _rootAlbums.remove((MediaTypeFilter.all, false));
      debugPrint('Count failed: $error');
      return null;
    }
  }

  Future<AssetEntity?> _assetFor(String id) async {
    final cached = _assets[id];
    if (cached != null) return cached;
    final asset = await AssetEntity.fromId(id); // returns null on failure
    if (asset != null) _assets[id] = asset;
    return asset;
  }

  @override
  Future<void> openSettings() => PhotoManager.openSetting();

  @override
  Future<void> manageLimitedSelection() =>
      PhotoManager.presentLimited(type: RequestType.common);

  @override
  void invalidate() {
    _rootAlbums.clear();
    _assets.clear();
  }

  // ---------------------------------------------------------------------------
  // Deletion
  // ---------------------------------------------------------------------------

  @override
  Future<DeletionMode> deletionMode() async {
    return _deletionMode ??= switch (_platform) {
      TargetPlatform.iOS => DeletionMode.recentlyDeleted,
      TargetPlatform.android => await _androidMode(),
      _ => DeletionMode.unsupported,
    };
  }

  Future<DeletionMode> _androidMode() async {
    final sdk = await _info.androidSdkInt();
    // Unknown version: assume the stricter outcome so we never understate it.
    if (sdk == null) return DeletionMode.permanent;
    return sdk >= 30 ? DeletionMode.trash : DeletionMode.permanent;
  }

  @override
  Future<Set<String>> findMissing(List<MediaItem> items) async {
    // Without read access every lookup fails, which would wrongly look like
    // "everything is missing". Report nothing instead.
    if (!(await checkAccess()).canReadMedia) return const {};
    final missing = <String>{};
    // Look up in small parallel batches; fresh lookups, not the cache.
    for (var start = 0; start < items.length; start += 20) {
      final batch = items.skip(start).take(20).toList();
      final found = await Future.wait(
        batch.map((item) => AssetEntity.fromId(item.id)),
      );
      for (var i = 0; i < batch.length; i++) {
        if (found[i] == null) missing.add(batch[i].id);
      }
    }
    return missing;
  }

  @override
  Future<DeletionResult> deleteMedia(List<MediaItem> items) async {
    final mode = await deletionMode();
    final requested = {for (final item in items) item.id};
    if (requested.isEmpty) {
      return DeletionResult(status: DeletionStatus.success, mode: mode);
    }

    final MediaAccess access;
    try {
      access = await checkAccess();
    } catch (error) {
      return DeletionResult(
        status: DeletionStatus.failed,
        mode: mode,
        failedIds: requested,
        message: '$error',
      );
    }
    if (!access.canReadMedia) {
      return DeletionResult(
        status: DeletionStatus.permissionDenied,
        mode: mode,
        failedIds: requested,
      );
    }

    // Items already gone are reported separately, so iOS's "all or nothing"
    // success reply can't make a missing item look freshly deleted.
    final missing = await findMissing(items);
    final toDelete = items.where((item) => !missing.contains(item.id)).toList();

    var returned = const <String>[];
    Object? error;
    if (toDelete.isNotEmpty) {
      try {
        if (mode == DeletionMode.trash) {
          final assets = <AssetEntity>[];
          for (final item in toDelete) {
            final asset = await _assetFor(item.id);
            if (asset != null) assets.add(asset);
          }
          returned = await PhotoManager.editor.android.moveToTrash(assets);
        } else {
          returned = await PhotoManager.editor.deleteWithIds(
            toDelete.map((item) => item.id).toList(),
          );
        }
      } catch (e) {
        error = e;
        debugPrint('Deletion failed: $e');
      }
    }

    for (final id in returned) {
      _assets.remove(id);
    }
    invalidate();
    return classifyDeletion(
      mode: mode,
      requestedIds: requested,
      missingIds: missing,
      returnedIds: returned.toSet(),
      error: error,
    );
  }
}

/// Turns the platform's reply into a [DeletionResult].
///
/// Both platforms show one system prompt and reply with the ids removed, or
/// an empty list if the user cancelled. Android 10 may remove only some.
DeletionResult classifyDeletion({
  required DeletionMode mode,
  required Set<String> requestedIds,
  required Set<String> missingIds,
  required Set<String> returnedIds,
  Object? error,
}) {
  final attempted = requestedIds.difference(missingIds);
  final deleted = returnedIds.intersection(attempted);
  final failed = attempted.difference(deleted);

  final DeletionStatus status;
  if (failed.isEmpty) {
    status = DeletionStatus.success;
  } else if (deleted.isNotEmpty) {
    status = DeletionStatus.partial;
  } else if (error != null) {
    status = DeletionStatus.failed;
  } else {
    status = DeletionStatus.cancelled;
  }

  return DeletionResult(
    status: status,
    mode: mode,
    deletedIds: deleted,
    missingIds: missingIds.intersection(requestedIds),
    failedIds: failed,
    message: error?.toString(),
  );
}

/// Maps the plugin's request type for each gallery filter.
RequestType requestTypeFor(MediaTypeFilter type) => switch (type) {
  MediaTypeFilter.all => RequestType.common,
  MediaTypeFilter.photos => RequestType.image,
  MediaTypeFilter.videos => RequestType.video,
};

/// Converts the plugin's permission state into Pictora's [MediaAccess].
///
/// photo_manager reports a single "denied" state. We refine it:
///  * iOS never shows the prompt again after a denial, so it's permanent.
///  * Android has no "not asked yet" state: a fresh install also reports
///    "denied". Until the user has actually said no in this session we treat
///    it as not asked, so the friendly Connect prompt is shown instead.
///  * Android stops showing the prompt after repeated denials, so a second
///    denial in the same session is treated as permanent.
MediaAccess mapPermissionState(
  PermissionState state, {
  required TargetPlatform platform,
  int deniedRequests = 0,
}) {
  if (state == PermissionState.denied && platform != TargetPlatform.iOS) {
    return switch (deniedRequests) {
      0 => MediaAccess.notDetermined,
      1 => MediaAccess.denied,
      _ => MediaAccess.permanentlyDenied,
    };
  }
  return switch (state) {
    PermissionState.notDetermined => MediaAccess.notDetermined,
    PermissionState.authorized => MediaAccess.granted,
    PermissionState.limited => MediaAccess.limited,
    PermissionState.restricted => MediaAccess.restricted,
    PermissionState.denied => MediaAccess.permanentlyDenied, // iOS
  };
}

/// Converts a plugin [AssetEntity] into a [MediaItem], or null for media
/// types the gallery doesn't show (audio, other).
MediaItem? mediaItemFromAsset(AssetEntity asset) {
  final kind = switch (asset.type) {
    AssetType.image => MediaKind.photo,
    AssetType.video => MediaKind.video,
    _ => null,
  };
  if (kind == null) return null;

  // Prefer the capture date; fall back to the modified date; else unknown.
  final created = (asset.createDateSecond ?? 0) > 0
      ? asset.createDateTime
      : (asset.modifiedDateSecond ?? 0) > 0
      ? asset.modifiedDateTime
      : null;

  final title = asset.title;
  return MediaItem(
    id: asset.id,
    kind: kind,
    createdAt: created,
    width: asset.orientatedWidth,
    height: asset.orientatedHeight,
    duration: kind == MediaKind.video && asset.duration > 0
        ? Duration(seconds: asset.duration)
        : null,
    title: title == null || title.isEmpty ? null : title,
    mimeType: asset.mimeType,
    isDeviceFavorite: asset.isFavorite,
  );
}
