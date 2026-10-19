import 'dart:io';
import 'dart:typed_data';

import 'media_access.dart';
import 'media_item.dart';

/// Which kinds of media a page request should return.
enum MediaTypeFilter { all, photos, videos }

/// Extra information that is slower to fetch, so it's loaded on demand
/// (for example when a photo is opened), never for the whole library.
class MediaDetails {
  const MediaDetails({this.fileSizeBytes, this.mimeType});

  final int? fileSizeBytes;
  final String? mimeType;
}

/// Where a playable video lives: a file on the device, or a bundled asset.
sealed class VideoSource {
  const VideoSource();
}

class FileVideoSource extends VideoSource {
  const FileVideoSource(this.file);

  final File file;
}

class AssetVideoSource extends VideoSource {
  const AssetVideoSource(this.assetPath);

  final String assetPath;
}

/// A friendly, displayable error from the media layer.
class MediaLoadException implements Exception {
  const MediaLoadException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'MediaLoadException: $message ($cause)';
}

/// What happens to media when the device deletes it. Decides the wording of
/// the confirmation and result screens (we never overstate freed space).
enum DeletionMode {
  /// iOS: items move to "Recently Deleted" for 30 days.
  recentlyDeleted,

  /// Android 11+: items move to the system trash for about 30 days.
  trash,

  /// Android 10 and below: items are deleted permanently.
  permanent,

  /// Deletion isn't possible (e.g. bundled demo photos).
  unsupported,
}

enum DeletionStatus {
  /// Every requested item was removed.
  success,

  /// Some items were removed, others weren't.
  partial,

  /// The user declined the system prompt; nothing was removed.
  cancelled,

  /// Photo access is missing or too limited to delete.
  permissionDenied,

  /// The platform reported an error; nothing (more) was removed.
  failed,
}

/// The honest outcome of a deletion request.
class DeletionResult {
  const DeletionResult({
    required this.status,
    required this.mode,
    this.deletedIds = const {},
    this.missingIds = const {},
    this.failedIds = const {},
    this.message,
  });

  final DeletionStatus status;
  final DeletionMode mode;

  /// Confirmed removed by the platform.
  final Set<String> deletedIds;

  /// Were already gone before we asked (deleted elsewhere, or no longer
  /// shared under limited access). Safe to drop from the queue.
  final Set<String> missingIds;

  /// Requested but not removed (cancelled, failed, or skipped).
  final Set<String> failedIds;

  /// Technical detail for logs; never shown verbatim to users.
  final String? message;

  /// Ids that can leave the deletion queue.
  Set<String> get resolvedIds => {...deletedIds, ...missingIds};
}

/// Where the gallery gets its media from.
///
/// The UI only talks to this interface. The device implementation uses the
/// photo_manager plugin; the demo implementation serves bundled photos; tests
/// use a fake. Swapping one for another needs no widget changes.
abstract class MediaRepository {
  /// Reads the current permission state WITHOUT showing any prompt.
  Future<MediaAccess> checkAccess();

  /// Asks the user for access. May show the system permission dialog.
  Future<MediaAccess> requestAccess();

  /// Returns one page of media, newest first (or oldest first when
  /// [oldestFirst] is true). The platform does the sorting, so paging stays
  /// consistent. An empty or short page means there is nothing more.
  Future<List<MediaItem>> fetchPage({
    required MediaTypeFilter type,
    required int page,
    required int pageSize,
    bool oldestFirst = false,
  });

  /// Small encoded image (e.g. JPEG bytes) for [item], or null if the file is
  /// missing or can't be read. Must never throw.
  Future<Uint8List?> loadThumbnail(
    MediaItem item, {
    required int width,
    required int height,
  });

  /// Where the video player can open a video [item], or null when it can't
  /// be read (deleted, not downloaded, or not a video). Must never throw.
  Future<VideoSource?> loadVideo(MediaItem item);

  /// File size and type for [item]. Fields are null when unavailable.
  Future<MediaDetails> loadDetails(MediaItem item);

  /// Just the file size in bytes (cheaper than [loadDetails]), or null if
  /// unknown. Never throws.
  Future<int?> fileSize(MediaItem item);

  /// How many photos and videos are accessible, or null if unknown.
  Future<int?> mediaCount();

  /// Opens this app's page in the system Settings app.
  Future<void> openSettings();

  /// Lets the user change which photos are shared under limited access.
  Future<void> manageLimitedSelection();

  /// Forgets cached library information so the next fetch re-reads it.
  void invalidate();

  /// How deletion behaves on this platform.
  Future<DeletionMode> deletionMode();

  /// Ids from [items] that no longer exist in the library.
  Future<Set<String>> findMissing(List<MediaItem> items);

  /// Asks the platform to delete [items]. This shows the system's own
  /// confirmation (where the platform has one) and never throws: every
  /// outcome is described by the returned [DeletionResult].
  Future<DeletionResult> deleteMedia(List<MediaItem> items);
}
