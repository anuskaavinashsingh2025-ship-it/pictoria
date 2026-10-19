import 'package:flutter/foundation.dart';

import '../data/media/media_item.dart';
import '../data/media/media_repository.dart';
import '../data/media/platform_info.dart';
import 'gallery_controller.dart';

enum InsightsStatus {
  /// Nothing scanned yet.
  idle,

  /// Showing bundled demo photos: there's no real library to measure.
  demo,

  /// Pictora can't read the photo library.
  noAccess,

  /// Measuring file sizes.
  scanning,

  /// Scan complete.
  ready,

  /// The scan failed.
  error,
}

/// A media item with its measured file size.
class SizedMedia {
  const SizedMedia(this.item, this.bytes);

  final MediaItem item;
  final int bytes;
}

/// Measured totals for the media Pictora can access. Every number here comes
/// from real file sizes reported by the platform; items whose size couldn't
/// be read are counted in [unknownSizeCount] instead of being guessed.
class LibraryStats {
  int photoCount = 0;
  int videoCount = 0;
  int photoBytes = 0;
  int videoBytes = 0;
  int unknownSizeCount = 0;
  final sizes = <String, int>{};

  /// Every measured item, in library order.
  final items = <MediaItem>[];
  final largeVideos = <SizedMedia>[];

  int get mediaBytes => photoBytes + videoBytes;
  int get itemCount => photoCount + videoCount;
  int get largeVideoBytes =>
      largeVideos.fold(0, (sum, video) => sum + video.bytes);
}

/// Computes the Insights numbers: device storage (from the OS) and the size
/// of the accessible photo library (by measuring each file).
///
/// The scan runs only when Insights is opened, page by page with a few size
/// lookups at a time, and is reused until the library changes.
class InsightsController extends ChangeNotifier {
  InsightsController({
    required this.gallery,
    PlatformInfo? platform,
    this.largeVideoThresholdBytes = 100 * 1000 * 1000,
    this.pageSize = 200,
    this.concurrency = 8,
  }) : _platform = platform ?? const PlatformInfo();

  final GalleryController gallery;
  final PlatformInfo _platform;

  /// Videos at least this big count as "large" (100 MB by default).
  final int largeVideoThresholdBytes;
  final int pageSize;

  /// How many file sizes are requested from the platform at once.
  final int concurrency;

  InsightsStatus _status = InsightsStatus.idle;
  LibraryStats _stats = LibraryStats();
  DeviceStorage? _storage;
  bool _storageLoaded = false;
  int _scanned = 0;
  int? _expected;
  int _scannedVersion = -1;
  int _scanToken = 0;
  bool _measuring = false;
  bool _measureFailed = false;
  bool _disposed = false;

  InsightsStatus get status => _status;
  LibraryStats get stats => _stats;

  /// Real device storage, or null if the platform couldn't report it.
  DeviceStorage? get storage => _storage;
  bool get storageLoaded => _storageLoaded;

  /// Scan progress: items measured so far, and the expected total if known.
  int get scannedCount => _scanned;
  int? get expectedCount => _expected;

  bool get isScanning => _status == InsightsStatus.scanning;

  /// True when the library changed since the last complete scan.
  bool get isStale => gallery.libraryVersion != _scannedVersion;

  /// Space used by everything except the measured media: apps, system data,
  /// and any media Pictora can't see. Null when it can't be worked out
  /// honestly (no device figures, or the scan isn't finished).
  int? get everythingElseBytes {
    final storage = _storage;
    if (storage == null || _status != InsightsStatus.ready) return null;
    return (storage.usedBytes - _stats.mediaBytes).clamp(0, storage.usedBytes);
  }

  /// Measured size of [item] from the scan, if known.
  int? sizeOf(MediaItem item) => _stats.sizes[item.id];

  /// Refreshes device storage, and rescans the library if it changed.
  Future<void> refreshIfNeeded() async {
    _loadStorage();
    await ensureMeasured();
  }

  /// Measures the library unless an up-to-date measurement already exists
  /// (or is running). Used by Insights and by the Gallery's size filters.
  Future<void> ensureMeasured() async {
    if (gallery.isCheckingAccess) return; // try again once access is known
    if (!isStale && (_measuring || _scannedVersion >= 0)) return;
    await scan();
  }

  Future<void> _loadStorage() async {
    final storage = await _platform.deviceStorage();
    if (_disposed) return;
    _storage = storage;
    _storageLoaded = true;
    _notify();
  }

  /// True while sizes are being measured (device or demo library).
  bool get isMeasuring => _measuring;

  /// True when every accessible item has been measured for the current
  /// library, so size sorting and filtering can be trusted.
  bool get sizesReady =>
      !_measuring &&
      !isStale &&
      !_measureFailed &&
      (_status == InsightsStatus.ready || _status == InsightsStatus.demo);

  /// True if the last measurement failed.
  bool get measureFailed => _measureFailed && !_measuring;

  /// Every measured item (in library order), for size sorting/filtering.
  List<MediaItem> get allItems => _stats.items;

  /// Measures every accessible photo and video. A newer call, a library
  /// change or dispose() cancels an older scan.
  ///
  /// In demo mode the bundled photos are measured too (their real file
  /// sizes), so the Gallery's size filters work, but Insights keeps showing
  /// its "demo" state rather than presenting them as your library.
  Future<void> scan() async {
    final token = ++_scanToken;
    final version = gallery.libraryVersion;
    final demo = gallery.isShowingDemo;

    if (!demo && !gallery.access.canReadMedia) {
      _stats = LibraryStats();
      _finish(InsightsStatus.noAccess, version);
      return;
    }

    final repository = gallery.activeRepository;
    final stats = LibraryStats();
    _stats = stats;
    _scanned = 0;
    _expected = null;
    _measuring = true;
    _measureFailed = false;
    _status = demo ? InsightsStatus.demo : InsightsStatus.scanning;
    _notify();

    bool cancelled() => _disposed || token != _scanToken;

    try {
      _expected = await repository.mediaCount();
      if (cancelled()) return;
      _notify();

      for (var page = 0; ; page++) {
        final items = await repository.fetchPage(
          type: MediaTypeFilter.all,
          page: page,
          pageSize: pageSize,
        );
        if (cancelled()) return;

        for (var start = 0; start < items.length; start += concurrency) {
          final batch = items.skip(start).take(concurrency).toList();
          final sizes = await Future.wait(batch.map(repository.fileSize));
          if (cancelled()) return;
          for (var i = 0; i < batch.length; i++) {
            _record(stats, batch[i], sizes[i]);
          }
          _scanned += batch.length;
          _notify();
        }
        if (items.length < pageSize) break;
      }
    } catch (error) {
      if (cancelled()) return;
      debugPrint('Insights scan failed: $error');
      _measuring = false;
      _measureFailed = true;
      _scannedVersion = version;
      _status = demo ? InsightsStatus.demo : InsightsStatus.error;
      _notify();
      return;
    }

    stats.largeVideos.sort((a, b) => b.bytes.compareTo(a.bytes));
    _measuring = false;
    _finish(demo ? InsightsStatus.demo : InsightsStatus.ready, version);
  }

  void _record(LibraryStats stats, MediaItem item, int? bytes) {
    stats.items.add(item);
    if (item.isVideo) {
      stats.videoCount++;
    } else {
      stats.photoCount++;
    }
    if (bytes == null) {
      stats.unknownSizeCount++;
      return;
    }
    stats.sizes[item.id] = bytes;
    if (item.isVideo) {
      stats.videoBytes += bytes;
      if (bytes >= largeVideoThresholdBytes) {
        stats.largeVideos.add(SizedMedia(item, bytes));
      }
    } else {
      stats.photoBytes += bytes;
    }
  }

  void _finish(InsightsStatus status, int version) {
    _status = status;
    _scannedVersion = version;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
