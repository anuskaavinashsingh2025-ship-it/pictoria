import 'package:flutter/foundation.dart';

import '../data/media/media_filters.dart';
import '../data/media/media_item.dart';
import '../data/media/media_repository.dart';
import '../data/review/review_record.dart';
import '../data/review/review_store.dart';
import 'gallery_controller.dart';

export '../data/review/review_record.dart' show ReviewDecision;

/// One step in the undo history.
class ReviewAction {
  const ReviewAction(this.item, this.decision);

  final MediaItem item;
  final ReviewDecision decision;
}

/// State for Swipe Review and the deletion queue.
///
/// It reuses the [GalleryController]'s "All" feed (same repository, paging
/// and thumbnails) and adds the user's decisions on top. Decisions are saved
/// through a [ReviewStore], so they survive navigation and app restarts.
///
/// "Delete" here only *marks* an item. Actual deletion happens solely in the
/// confirmed flow (DeletionController → GalleryController.deleteMedia), and
/// its results come back through [applyDeletionResult].
class ReviewController extends ChangeNotifier {
  ReviewController({
    required this.gallery,
    ReviewStore? store,
    this.prefetchThreshold = 8,
  }) : _store = store ?? MemoryReviewStore(),
       _lastSource = gallery.source {
    gallery.addListener(_onGalleryChanged);
  }

  final GalleryController gallery;
  final ReviewStore _store;

  /// Load the next page when fewer than this many cards remain.
  final int prefetchThreshold;

  final _records = <String, ReviewRecord>{};
  final _history = <ReviewAction>[];

  /// Ids confirmed deleted this session: never shown or "undone" again.
  final _deletedIds = <String>{};

  /// Ids from a deletion request whose outcome was never recorded.
  Set<String> _pendingDeletion = {};

  bool _restored = false;
  bool _disposed = false;
  LibrarySource _lastSource;
  Future<void> _saving = Future.value();

  MediaFeed get _feed => gallery.feedFor(MediaTypeFilter.all);
  List<MediaItem> get _all => _feed.items;

  bool _hasDecision(MediaItem item) =>
      _records.containsKey(item.id) || _deletedIds.contains(item.id);

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// True once saved decisions have been loaded.
  bool get isRestored => _restored;

  /// Loads saved decisions. Call once at startup.
  Future<void> restore() async {
    if (_restored) return;
    final snapshot = await _store.load();
    if (_disposed) return;
    // Anything decided before loading finished wins over the saved copy.
    for (final entry in snapshot.records.entries) {
      _records.putIfAbsent(entry.key, () => entry.value);
    }
    _pendingDeletion = {...snapshot.pendingDeletionIds};
    _restored = true;
    _notify();
  }

  /// Saves in order; a failed save is logged but never breaks the UI.
  void _persist() {
    final snapshot = ReviewSnapshot(
      records: Map.of(_records),
      pendingDeletionIds: Set.of(_pendingDeletion),
    );
    _saving = _saving.then((_) => _store.save(snapshot)).catchError((
      Object error,
    ) {
      debugPrint('Could not save review data: $error');
    });
  }

  /// Completes when all pending saves have finished (useful in tests).
  Future<void> flush() => _saving;

  // ---------------------------------------------------------------------------
  // Swipe review queue
  // ---------------------------------------------------------------------------

  /// Items that still need a decision, in order.
  List<MediaItem> get queue =>
      _all.where((item) => !_hasDecision(item)).toList();

  /// The card on top, or null when there is nothing left to review.
  MediaItem? get current {
    for (final item in _all) {
      if (!_hasDecision(item)) return item;
    }
    return null;
  }

  /// The card underneath the top one (shown peeking behind it).
  MediaItem? get next {
    var foundCurrent = false;
    for (final item in _all) {
      if (_hasDecision(item)) continue;
      if (foundCurrent) return item;
      foundCurrent = true;
    }
    return null;
  }

  /// Counts over the media currently loaded (they drive the progress bar).
  int get keptCount => _all
      .where((item) => _records[item.id]?.decision == ReviewDecision.keep)
      .length;
  int get reviewedCount =>
      _all.where((item) => _records.containsKey(item.id)).length;
  int get totalCount => _all.length;

  /// Number of items in the deletion queue for the current library.
  int get markedCount => markedRecords.length;

  bool get hasMoreToLoad => _feed.hasMore;
  bool get isLoading =>
      gallery.isCheckingAccess || (_feed.isInitialLoad && _feed.error == null);
  Object? get loadError => _all.isEmpty ? _feed.error : null;

  bool get canUndo => _history.isNotEmpty;
  ReviewAction? get lastAction => _history.isEmpty ? null : _history.last;

  /// Fraction of loaded media reviewed so far (0–1).
  double get progress => totalCount == 0 ? 0 : reviewedCount / totalCount;

  ReviewDecision? decisionFor(MediaItem item) => _records[item.id]?.decision;

  /// Makes sure the first page is loaded (e.g. when the tab first opens).
  void ensureLoaded() {
    if (_feed.items.isEmpty && _feed.hasMore && !_feed.isLoading) {
      gallery.loadMore(type: MediaTypeFilter.all);
    }
  }

  void keep() => _decide(ReviewDecision.keep);

  /// Marks the current item for deletion. Does NOT delete anything.
  void markForDeletion() => _decide(ReviewDecision.delete);

  void _decide(ReviewDecision decision) {
    final item = current;
    if (item == null) return;
    _records[item.id] = ReviewRecord(
      item: item,
      decision: decision,
      decidedAt: DateTime.now(),
    );
    _history.add(ReviewAction(item, decision));
    _prefetchIfNeeded();
    _persist();
    _notify();
  }

  /// Reverts the most recent decision; that item becomes the top card again.
  /// Items that were already deleted are never brought back.
  ReviewAction? undo() {
    while (_history.isNotEmpty) {
      final action = _history.removeLast();
      if (_deletedIds.contains(action.item.id)) continue;
      _records.remove(action.item.id);
      _persist();
      _notify();
      return action;
    }
    return null;
  }

  /// Clears every decision for the current library and starts again.
  void startOver() {
    _records.removeWhere((_, record) => _belongsToCurrentSource(record));
    _history.clear();
    _persist();
    _notify();
  }

  void retry() => gallery.retry();

  // ---------------------------------------------------------------------------
  // Deletion queue
  // ---------------------------------------------------------------------------

  bool _belongsToCurrentSource(ReviewRecord record) =>
      record.item.isDemo == gallery.isShowingDemo;

  /// Marked items for the current library, newest first. These come from
  /// saved metadata, so they appear even if not loaded in the Gallery yet.
  List<ReviewRecord> get markedRecords {
    final marked = [
      for (final record in _records.values)
        if (record.decision == ReviewDecision.delete &&
            _belongsToCurrentSource(record))
          record,
    ];
    final byId = {for (final record in marked) record.id: record};
    return [
      for (final item in sortNewestFirst(marked.map((r) => r.item)))
        byId[item.id]!,
    ];
  }

  List<MediaItem> get markedForDeletion =>
      markedRecords.map((record) => record.item).toList();

  bool isMarked(MediaItem item) =>
      _records[item.id]?.decision == ReviewDecision.delete;

  /// Marks a specific item (e.g. from the Large videos list) without
  /// swiping. Like a swipe, this only adds it to the deletion queue.
  void markItemForDeletion(MediaItem item, {int? sizeBytes}) {
    if (_deletedIds.contains(item.id)) return;
    _records[item.id] = ReviewRecord(
      item: item,
      decision: ReviewDecision.delete,
      decidedAt: DateTime.now(),
      fileSizeBytes: sizeBytes,
    );
    _persist();
    _notify();
  }

  /// Puts a marked item back into the swipe queue (it gets a fresh look).
  void restoreToReview(MediaItem item) {
    if (_records[item.id]?.decision != ReviewDecision.delete) return;
    _records.remove(item.id);
    _history.removeWhere((action) => action.item.id == item.id);
    _persist();
    _notify();
  }

  /// Kept for the earlier marked-items API.
  void unmark(MediaItem item) => restoreToReview(item);

  /// Remembers a file size once it's known, so it shows instantly next time.
  void rememberSize(String id, int bytes) {
    final record = _records[id];
    if (record == null || record.fileSizeBytes == bytes) return;
    _records[id] = record.copyWith(fileSizeBytes: bytes);
    _persist();
  }

  /// Ids whose deletion outcome is unknown (the app stopped mid-request).
  Set<String> get interruptedDeletionIds => Set.unmodifiable(_pendingDeletion);

  /// Records that a deletion request is starting, before asking the system.
  void beginDeletion(Iterable<String> ids) {
    _pendingDeletion = {..._pendingDeletion, ...ids};
    _persist();
  }

  /// Applies a deletion outcome: only confirmed-removed items leave the
  /// queue; everything else stays marked.
  void applyDeletionResult(DeletionResult result, Iterable<String> requested) {
    _forget(result.resolvedIds);
    _pendingDeletion = _pendingDeletion.difference(requested.toSet());
    _persist();
    _notify();
  }

  /// Drops items that no longer exist on the device from the queue.
  void removeMissing(Set<String> ids) {
    if (ids.isEmpty) return;
    _forget(ids);
    _pendingDeletion = _pendingDeletion.difference(ids);
    _persist();
    _notify();
  }

  /// Clears the interrupted-deletion marker once it has been checked.
  void clearInterrupted(Iterable<String> ids) {
    _pendingDeletion = _pendingDeletion.difference(ids.toSet());
    _persist();
    _notify();
  }

  void _forget(Set<String> ids) {
    _deletedIds.addAll(ids);
    _records.removeWhere((id, _) => ids.contains(id));
    _history.removeWhere((action) => ids.contains(action.item.id));
  }

  // ---------------------------------------------------------------------------

  void _prefetchIfNeeded() {
    if (!_feed.hasMore || _feed.isLoading) return;
    if (queue.length < prefetchThreshold) {
      gallery.loadMore(type: MediaTypeFilter.all);
    }
  }

  void _onGalleryChanged() {
    // New pages, a source switch or a refresh all change the queue.
    if (gallery.source != _lastSource) {
      // Undo history refers to the other library's items; start fresh.
      _lastSource = gallery.source;
      _history.clear();
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    gallery.removeListener(_onGalleryChanged);
    super.dispose();
  }
}
