import 'package:flutter/foundation.dart';

import '../data/media/media_repository.dart';
import '../data/review/review_record.dart';
import 'gallery_controller.dart';
import 'review_controller.dart';

enum DeletionPhase {
  /// Checking which marked items still exist.
  checking,

  /// Showing the queue; the user can select and confirm.
  ready,

  /// A deletion request is with the system.
  deleting,

  /// A request finished; [DeletionController.lastResult] describes it.
  finished,
}

/// State for the deletion queue and confirmation screens.
///
/// Safety rules it enforces:
///  * Nothing is deleted until [deleteSelected] is called from the explicit
///    confirmation screen.
///  * Only one request can run at a time.
///  * Only items the platform confirms as removed leave the queue.
class DeletionController extends ChangeNotifier {
  DeletionController({required this.review});

  final ReviewController review;
  GalleryController get gallery => review.gallery;

  DeletionPhase _phase = DeletionPhase.checking;
  DeletionMode _mode = DeletionMode.unsupported;

  /// Deselected ids (so newly marked items are selected by default).
  final _deselected = <String>{};
  final _sizes = <String, int>{};
  final _sizeUnavailable = <String>{};

  DeletionResult? _lastResult;
  int _lastRequestedCount = 0;
  int _lastDeletedBytes = 0;
  bool _started = false;
  bool _disposed = false;

  /// Items found already missing when the queue was opened.
  int missingRemovedCount = 0;

  /// From an interrupted earlier request: how many turned out deleted, and
  /// how many are still on the device (and still marked).
  int interruptedDeletedCount = 0;
  int interruptedRemainingCount = 0;

  DeletionPhase get phase => _phase;
  DeletionMode get mode => _mode;
  DeletionResult? get lastResult => _lastResult;
  int get lastRequestedCount => _lastRequestedCount;

  /// Bytes of items confirmed deleted in the last request (known sizes only).
  int get lastDeletedBytes => _lastDeletedBytes;

  bool get isDemo => gallery.isShowingDemo;

  List<ReviewRecord> get records => review.markedRecords;

  bool isSelected(ReviewRecord record) => !_deselected.contains(record.id);

  List<ReviewRecord> get selected => records.where(isSelected).toList();
  int get selectedCount => selected.length;

  /// Size in bytes, or null if not known (yet).
  int? sizeOf(ReviewRecord record) => _sizes[record.id] ?? record.fileSizeBytes;

  bool isSizeUnavailable(ReviewRecord record) =>
      sizeOf(record) == null && _sizeUnavailable.contains(record.id);

  /// Combined size of the selected items whose size is known.
  int get selectedBytes =>
      selected.fold(0, (sum, record) => sum + (sizeOf(record) ?? 0));

  /// How many selected items have no known size.
  int get unknownSizeCount =>
      selected.where((record) => sizeOf(record) == null).length;

  bool get canDelete =>
      _phase == DeletionPhase.ready &&
      _mode != DeletionMode.unsupported &&
      selectedCount > 0;

  /// Checks marked items against the library, then loads their sizes.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    review.addListener(_onReviewChanged);

    _mode = await gallery.deletionModeFor(demo: isDemo);
    if (_disposed) return;

    final items = records.map((record) => record.item).toList();
    final missing = await gallery.findMissing(items);
    if (_disposed) return;

    // Resolve a deletion that was interrupted (e.g. the app was closed while
    // the system prompt was open): gone means deleted, present means kept.
    final pending = review.interruptedDeletionIds;
    if (pending.isNotEmpty) {
      final markedIds = {for (final record in records) record.id};
      interruptedDeletedCount = pending.intersection(missing).length;
      interruptedRemainingCount = pending
          .intersection(markedIds)
          .difference(missing)
          .length;
      review.clearInterrupted(pending);
    }
    missingRemovedCount = missing.difference(pending).length;
    review.removeMissing(missing);

    _phase = DeletionPhase.ready;
    _notify();
    await _loadSizes();
  }

  Future<void> _loadSizes() async {
    for (final record in records) {
      if (_disposed) return;
      if (sizeOf(record) != null) continue;
      final details = await gallery.detailsFor(record.item);
      final bytes = details.fileSizeBytes;
      if (bytes != null && bytes > 0) {
        _sizes[record.id] = bytes;
        review.rememberSize(record.id, bytes);
      } else {
        _sizeUnavailable.add(record.id);
      }
      _notify();
    }
  }

  void toggle(ReviewRecord record) {
    if (!_deselected.remove(record.id)) _deselected.add(record.id);
    _notify();
  }

  void selectAll() {
    _deselected.clear();
    _notify();
  }

  void selectNone() {
    _deselected.addAll(records.map((record) => record.id));
    _notify();
  }

  /// Sends the selected items to the platform for deletion.
  ///
  /// Call this only from the confirmation screen's Continue button. Extra
  /// calls while a request is running are ignored.
  Future<DeletionResult?> deleteSelected() async {
    if (!canDelete) return null;
    final targets = selected;
    final ids = [for (final record in targets) record.id];
    final sizes = {for (final record in targets) record.id: sizeOf(record)};

    _phase = DeletionPhase.deleting;
    _notify();

    // Saved first, so an interrupted request can be reconciled next time.
    review.beginDeletion(ids);
    final result =
        await gallery.deleteMedia([for (final r in targets) r.item]) ??
        DeletionResult(
          status: DeletionStatus.failed,
          mode: _mode,
          failedIds: ids.toSet(),
          message: 'Another deletion is already running',
        );
    review.applyDeletionResult(result, ids);

    _lastResult = result;
    _lastRequestedCount = ids.length;
    _lastDeletedBytes = result.deletedIds.fold(
      0,
      (sum, id) => sum + (sizes[id] ?? 0),
    );
    _phase = DeletionPhase.finished;
    _notify();
    return result;
  }

  /// Returns to the queue after the user has read the result.
  void acknowledgeResult() {
    if (_phase != DeletionPhase.finished) return;
    _phase = DeletionPhase.ready;
    _notify();
  }

  void _onReviewChanged() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    review.removeListener(_onReviewChanged);
    super.dispose();
  }
}
