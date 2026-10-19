import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../data/media/demo_media_repository.dart';
import '../data/media/media_access.dart';
import '../data/media/media_filters.dart';
import '../data/media/media_item.dart';
import '../data/media/media_repository.dart';
import '../data/media/media_thumbnail_provider.dart';

/// Where the gallery's media currently comes from.
enum LibrarySource { demo, device }

/// The loaded pages for one filter type (All / Photos / Videos).
class MediaFeed {
  List<MediaItem> items = const [];
  int nextPage = 0;
  bool hasMore = true;
  bool isLoading = false;

  /// The last loading error, shown with a Retry button.
  Object? error;

  bool get isInitialLoad => items.isEmpty && (isLoading || hasMore);
}

/// Holds the Gallery's state and talks to the repositories.
///
/// It is a [ChangeNotifier]: widgets listen to it (with ListenableBuilder)
/// and rebuild when it calls [notifyListeners]. It lives in HomeShell, so its
/// loaded pages survive tab switches and trips to the viewer — the library is
/// only re-read when access changes or the user pulls to refresh.
class GalleryController extends ChangeNotifier {
  GalleryController({
    required MediaRepository deviceRepository,
    MediaRepository? demoRepository,
    Set<String>? initialFavorites,
    this.pageSize = 120,
  }) : _device = deviceRepository,
       _demo = demoRepository ?? DemoMediaRepository(),
       favorites = initialFavorites ?? DemoMediaRepository.initialFavoriteIds;

  final MediaRepository _device;
  final MediaRepository _demo;
  final int pageSize;

  MediaAccess _access = MediaAccess.unknown;
  LibrarySource _source = LibrarySource.demo;
  MediaTypeFilter _type = MediaTypeFilter.all;

  /// True when the user picked demo mode even though they have access.
  bool _userChoseDemo = false;

  /// True while a system prompt or picker is open (they pause the app, and
  /// we don't want the resume event to trigger a second reload).
  bool _systemUiOpen = false;

  bool _initialized = false;
  bool _disposed = false;

  /// Bumped whenever loaded data is thrown away. Async results that started
  /// under an older generation are ignored, so a slow page from the previous
  /// source can never overwrite the new one.
  int _generation = 0;

  /// Loaded pages per (type, oldest-first) combination.
  final _feeds = <(MediaTypeFilter, bool), MediaFeed>{};

  /// The Gallery's date order. Review and Insights always use newest first.
  bool _oldestFirst = false;

  /// Every item loaded so far for the current source, by id.
  final _known = <String, MediaItem>{};

  final _details = <String, Future<MediaDetails>>{};

  /// Pictora's own favorites (ids). Kept in memory for this milestone.
  final Set<String> favorites;

  MediaAccess get access => _access;

  /// Changes whenever loaded media is thrown away (source switch, refresh,
  /// deletion), so other screens know their derived data is out of date.
  int get libraryVersion => _generation;

  /// The repository for the current source (used by Insights to scan).
  MediaRepository get activeRepository => _active;
  LibrarySource get source => _source;
  MediaTypeFilter get typeFilter => _type;
  bool get isCheckingAccess => _access == MediaAccess.unknown;
  bool get isShowingDemo => _source == LibrarySource.demo;

  MediaRepository get _active =>
      _source == LibrarySource.device ? _device : _demo;

  /// The pages loaded for the current filter type.
  MediaFeed get feed => feedFor(_type, oldestFirst: _oldestFirst);

  bool get oldestFirst => _oldestFirst;

  /// The pages loaded for a specific type (Review always uses "all").
  MediaFeed feedFor(MediaTypeFilter type, {bool oldestFirst = false}) =>
      _feeds.putIfAbsent((type, oldestFirst), MediaFeed.new);

  /// Loaded items the user has hearted, newest first.
  List<MediaItem> get favoriteItems =>
      sortNewestFirst(favorites.map((id) => _known[id]).whereType<MediaItem>());

  // ---------------------------------------------------------------------------
  // Access and source
  // ---------------------------------------------------------------------------

  /// Checks permission silently (no prompt) and loads the first page.
  /// Safe to call more than once.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _access = await _checkAccessSafely();
    _source = _access.canReadMedia ? LibrarySource.device : LibrarySource.demo;
    _resetData();
    await loadMore();
  }

  /// Called when the user taps "Connect library" or "Try again". This is the
  /// only place the system permission prompt can appear.
  Future<void> connectLibrary() async {
    _systemUiOpen = true;
    try {
      _access = await _device.requestAccess();
    } catch (error) {
      debugPrint('Permission request failed: $error');
    } finally {
      _systemUiOpen = false;
    }
    if (_disposed) return;
    if (_access.canReadMedia) {
      _userChoseDemo = false;
      _switchTo(LibrarySource.device);
    } else {
      _notify();
    }
  }

  Future<void> openSettings() => _device.openSettings();

  /// Lets a limited-access user change their selection, then reloads.
  Future<void> manageLimitedSelection() async {
    _systemUiOpen = true;
    try {
      await _device.manageLimitedSelection();
    } catch (error) {
      debugPrint('Limited picker failed: $error');
    } finally {
      _systemUiOpen = false;
    }
    if (_disposed) return;
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Deletion (only ever called from the confirmed deletion flow)
  // ---------------------------------------------------------------------------

  bool _deleting = false;

  /// True while a deletion request is with the system.
  bool get isDeleting => _deleting;

  MediaRepository _repositoryFor(List<MediaItem> items) =>
      items.isNotEmpty && items.first.isDemo ? _demo : _device;

  Future<DeletionMode> deletionModeFor({required bool demo}) =>
      (demo ? _demo : _device).deletionMode();

  Future<Set<String>> findMissing(List<MediaItem> items) async {
    if (items.isEmpty) return const {};
    try {
      return await _repositoryFor(items).findMissing(items);
    } catch (error) {
      debugPrint('Missing-file check failed: $error');
      return const {};
    }
  }

  /// Asks the platform to delete [items] and refreshes the Gallery if
  /// anything was removed. A second call while one is running is ignored.
  Future<DeletionResult?> deleteMedia(List<MediaItem> items) async {
    if (_deleting || items.isEmpty) return null;
    _deleting = true;
    // The system prompt can pause the app (Android); don't treat the
    // resume as a permission change mid-request.
    _systemUiOpen = true;
    _notify();
    DeletionResult result;
    try {
      result = await _repositoryFor(items).deleteMedia(items);
    } catch (error) {
      // Repositories shouldn't throw, but never let that crash the flow.
      result = DeletionResult(
        status: DeletionStatus.failed,
        mode: DeletionMode.unsupported,
        failedIds: {for (final item in items) item.id},
        message: '$error',
      );
    } finally {
      _systemUiOpen = false;
      _deleting = false;
    }
    if (_disposed) return result;

    final removed = result.resolvedIds;
    if (removed.isNotEmpty) {
      favorites.removeAll(removed);
      await refresh(); // re-read the library so deleted items disappear
    } else {
      _notify();
    }
    return result;
  }

  void useDemoMedia() {
    _userChoseDemo = true;
    _switchTo(LibrarySource.demo);
  }

  void useDeviceLibrary() {
    _userChoseDemo = false;
    if (_access.canReadMedia) {
      _switchTo(LibrarySource.device);
    } else {
      connectLibrary();
    }
  }

  /// Re-checks permission when the app returns to the foreground — the user
  /// may have changed it in Settings. Reloads only if something changed.
  Future<void> onAppResumed() async {
    if (!_initialized || _systemUiOpen || _disposed) return;
    final newAccess = await _checkAccessSafely();
    if (_disposed || newAccess == _access) return;
    _access = newAccess;

    if (!newAccess.canReadMedia && _source == LibrarySource.device) {
      _switchTo(LibrarySource.demo); // access was revoked
    } else if (newAccess.canReadMedia && !_userChoseDemo) {
      _switchTo(LibrarySource.device); // newly granted, or scope changed
    } else {
      _notify();
    }
  }

  Future<MediaAccess> _checkAccessSafely() async {
    try {
      return await _device.checkAccess();
    } catch (error) {
      // e.g. a platform without photo support: fall back to demo mode.
      debugPrint('Permission check failed: $error');
      return MediaAccess.notDetermined;
    }
  }

  void _switchTo(LibrarySource source) {
    _source = source;
    _resetData();
    loadMore();
  }

  // ---------------------------------------------------------------------------
  // Loading pages
  // ---------------------------------------------------------------------------

  /// Switches between All / Photos / Videos. Each type keeps its own pages,
  /// so switching back is instant.
  void setTypeFilter(MediaTypeFilter type) {
    if (type == _type) return;
    _type = type;
    _notify();
    if (feed.items.isEmpty && feed.hasMore) loadMore();
  }

  /// Switches the Gallery between newest-first and oldest-first. Each order
  /// keeps its own pages (sorted by the platform), so paging stays correct.
  void setOldestFirst(bool oldestFirst) {
    if (oldestFirst == _oldestFirst) return;
    _oldestFirst = oldestFirst;
    _notify();
    if (feed.items.isEmpty && feed.hasMore) loadMore();
  }

  /// Loads the next page for the current filter, if there is one.
  ///
  /// Pass [type] to page a specific feed regardless of the Gallery's chip
  /// and order (the Review screen always pages "all", newest first).
  Future<void> loadMore({MediaTypeFilter? type}) async {
    final requestType = type ?? _type;
    final requestOldest = type == null && _oldestFirst;
    final target = feedFor(requestType, oldestFirst: requestOldest);
    if (target.isLoading || !target.hasMore) return;

    final generation = _generation;
    final repository = _active;
    target
      ..isLoading = true
      ..error = null;
    _notify();

    try {
      final page = await repository.fetchPage(
        type: requestType,
        page: target.nextPage,
        pageSize: pageSize,
        oldestFirst: requestOldest,
      );
      if (_isStale(generation)) return;
      target
        ..items = mergeById(target.items, page)
        ..nextPage += 1
        ..hasMore = page.length >= pageSize;
      for (final item in page) {
        _known[item.id] = item;
      }
    } catch (error) {
      if (_isStale(generation)) return;
      target.error = error;
    } finally {
      if (!_isStale(generation)) {
        target.isLoading = false;
        _notify();
      }
    }
  }

  /// Throws away loaded pages and reloads (pull-to-refresh).
  Future<void> refresh() async {
    _active.invalidate();
    _resetData();
    await loadMore();
  }

  /// Retries after an error.
  Future<void> retry() => loadMore();

  void _resetData() {
    _generation++;
    _feeds.clear();
    _known.clear();
    _details.clear();
    _notify();
  }

  bool _isStale(int generation) => _disposed || generation != _generation;

  // ---------------------------------------------------------------------------
  // Favorites, thumbnails and details
  // ---------------------------------------------------------------------------

  bool isFavorite(MediaItem item) => favorites.contains(item.id);

  void toggleFavorite(MediaItem item) {
    if (!favorites.remove(item.id)) favorites.add(item.id);
    _notify();
  }

  /// An image for [item] about [pixelWidth] physical pixels wide.
  ///
  /// Widths are rounded up to steps of 128 px so slightly different tile
  /// sizes share the same cached thumbnail.
  ImageProvider thumbnailFor(MediaItem item, {required int pixelWidth}) {
    final width = (((pixelWidth / 128).ceil()) * 128).clamp(128, 2048);
    final assetPath = item.assetPath;
    if (assetPath != null) {
      return ResizeImage(AssetImage(assetPath), width: width);
    }
    final height = (width / item.aspectRatio).round().clamp(1, 4096);
    final repository = _device;
    return MediaThumbnailProvider(
      cacheKey: 'device:${item.id}',
      width: width,
      height: height,
      loader: () =>
          repository.loadThumbnail(item, width: width, height: height),
    );
  }

  /// Where to play a video [item] from, or null when it can't be played.
  /// Not cached: the platform may clean up exported files.
  Future<VideoSource?> videoFor(MediaItem item) =>
      (item.isDemo ? _demo : _device).loadVideo(item);

  /// File size and type, fetched once per item and then remembered.
  Future<MediaDetails> detailsFor(MediaItem item) {
    final repository = item.isDemo ? _demo : _device;
    return _details.putIfAbsent(item.id, () async {
      try {
        return await repository.loadDetails(item);
      } catch (error) {
        debugPrint('Details failed for ${item.id}: $error');
        return const MediaDetails();
      }
    });
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
