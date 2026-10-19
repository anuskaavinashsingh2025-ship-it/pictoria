import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/media/media_access.dart';
import 'package:pictoria/data/media/media_repository.dart';
import 'package:pictoria/data/review/review_record.dart';
import 'package:pictoria/data/review/review_store.dart';
import 'package:pictoria/state/deletion_controller.dart';
import 'package:pictoria/state/gallery_controller.dart';
import 'package:pictoria/state/review_controller.dart';

import '../support/fake_media_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMediaRepository device;
  late GalleryController gallery;
  late ReviewController review;
  late MemoryReviewStore store;

  Future<void> setUpWith({
    int items = 4,
    ReviewSnapshot snapshot = ReviewSnapshot.empty,
  }) async {
    device = FakeMediaRepository(items: fakeDeviceItems(items));
    store = MemoryReviewStore(snapshot);
    gallery = GalleryController(deviceRepository: device, initialFavorites: {});
    review = ReviewController(gallery: gallery, store: store);
    addTearDown(() {
      review.dispose();
      gallery.dispose();
    });
    await gallery.initialize();
    await review.restore();
  }

  Future<DeletionController> openQueue() async {
    final deletion = DeletionController(review: review);
    addTearDown(deletion.dispose);
    await deletion.start();
    return deletion;
  }

  test(
    'marks persist across a restart (new controllers, same store)',
    () async {
      await setUpWith();
      review
        ..markForDeletion()
        ..keep();
      await review.flush();

      // Simulate an app restart.
      final gallery2 = GalleryController(
        deviceRepository: device,
        initialFavorites: {},
      );
      final review2 = ReviewController(gallery: gallery2, store: store);
      addTearDown(() {
        review2.dispose();
        gallery2.dispose();
      });
      await gallery2.initialize();
      await review2.restore();

      expect(review2.markedForDeletion.map((m) => m.id), ['device-0']);
      expect(review2.decisionFor(gallery2.feed.items[1]), ReviewDecision.keep);
      expect(review2.current?.id, 'device-2');
    },
  );

  test(
    'everything marked starts selected; deselecting updates totals',
    () async {
      await setUpWith();
      review
        ..markForDeletion()
        ..markForDeletion();
      final deletion = await openQueue();

      expect(deletion.selectedCount, 2);
      expect(deletion.selectedBytes, 4096); // fake: 2 KB each

      deletion.toggle(deletion.records.first);
      expect(deletion.selectedCount, 1);
      expect(deletion.selectedBytes, 2048);

      deletion.selectNone();
      expect(deletion.canDelete, isFalse);
      expect(await deletion.deleteSelected(), isNull);
      expect(device.deleteCallCount, 0);
    },
  );

  test(
    'success removes only confirmed items and refreshes the Gallery',
    () async {
      await setUpWith();
      review
        ..markForDeletion()
        ..markForDeletion();
      final deletion = await openQueue();
      final fetchesBefore = device.fetchCount;

      final result = await deletion.deleteSelected();
      await review.flush();

      expect(result!.status, DeletionStatus.success);
      expect(review.markedCount, 0);
      expect(device.items.map((m) => m.id), ['device-2', 'device-3']);
      expect(device.fetchCount, greaterThan(fetchesBefore));
      expect(store.snapshot.records, isEmpty);
      expect(store.snapshot.pendingDeletionIds, isEmpty);
    },
  );

  test('cancelling keeps everything queued', () async {
    await setUpWith();
    review.markForDeletion();
    device.onDelete = (_) async => []; // user taps "Don't Allow"
    final deletion = await openQueue();

    final result = await deletion.deleteSelected();

    expect(result!.status, DeletionStatus.cancelled);
    expect(review.markedCount, 1);
    expect(device.items, hasLength(4));
  });

  test('partial success keeps the failed items queued', () async {
    await setUpWith();
    review
      ..markForDeletion()
      ..markForDeletion();
    device.onDelete = (ids) async => [ids.first];
    final deletion = await openQueue();

    final result = await deletion.deleteSelected();

    expect(result!.status, DeletionStatus.partial);
    expect(result.deletedIds, hasLength(1));
    expect(review.markedCount, 1);
  });

  test('a platform failure keeps everything queued', () async {
    await setUpWith();
    review.markForDeletion();
    device.deleteError = Exception('PHPhotosErrorDomain 3300');
    final deletion = await openQueue();

    final result = await deletion.deleteSelected();

    expect(result!.status, DeletionStatus.failed);
    expect(review.markedCount, 1);
    expect(deletion.phase, DeletionPhase.finished);
  });

  test('missing permission is reported and nothing is removed', () async {
    await setUpWith();
    review.markForDeletion();
    final deletion = await openQueue();
    device.access = MediaAccess.denied; // revoked before confirming

    final result = await deletion.deleteSelected();

    expect(result!.status, DeletionStatus.permissionDenied);
    expect(review.markedCount, 1);
  });

  test('a second request while one is running is ignored', () async {
    await setUpWith();
    review.markForDeletion();
    final gate = Completer<List<String>>();
    device.onDelete = (_) => gate.future;
    final deletion = await openQueue();

    final first = deletion.deleteSelected();
    final second = await deletion.deleteSelected();
    expect(second, isNull);
    expect(deletion.phase, DeletionPhase.deleting);

    gate.complete(['device-0']);
    await first;
    expect(device.deleteCallCount, 1);
  });

  test('items already gone are dropped when the queue opens', () async {
    await setUpWith();
    review
      ..markForDeletion()
      ..markForDeletion();
    device.missingIds = {'device-1'};

    final deletion = await openQueue();

    expect(deletion.missingRemovedCount, 1);
    expect(deletion.records.map((r) => r.id), ['device-0']);
  });

  test('an interrupted deletion is reconciled on the next visit', () async {
    // Last session: two items were sent for deletion, then the app died.
    final items = fakeDeviceItems(4);
    await setUpWith(
      snapshot: ReviewSnapshot(
        records: {
          for (final item in items.take(2))
            item.id: ReviewRecord(
              item: item,
              decision: ReviewDecision.delete,
              decidedAt: DateTime(2026, 10, 1),
            ),
        },
        pendingDeletionIds: {'device-0', 'device-1'},
      ),
    );
    device.missingIds = {'device-0'}; // that one did get deleted

    final deletion = await openQueue();
    await review.flush();

    expect(deletion.interruptedDeletedCount, 1);
    expect(deletion.interruptedRemainingCount, 1);
    expect(deletion.records.map((r) => r.id), ['device-1']);
    expect(store.snapshot.pendingDeletionIds, isEmpty);
  });

  test('undo never brings back an item that was deleted', () async {
    await setUpWith();
    review.markForDeletion(); // device-0
    final deletion = await openQueue();
    await deletion.deleteSelected();

    expect(review.undo(), isNull);
    expect(review.current?.id, isNot('device-0'));
  });

  test('demo photos can never be deleted', () async {
    await setUpWith();
    gallery.useDemoMedia();
    await pumpEventQueue();
    review.markForDeletion();
    final deletion = await openQueue();

    expect(deletion.mode, DeletionMode.unsupported);
    expect(deletion.canDelete, isFalse);
    expect(await deletion.deleteSelected(), isNull);
  });
}
