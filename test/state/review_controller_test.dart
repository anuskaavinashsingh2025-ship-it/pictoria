import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/media/media_repository.dart';
import 'package:pictoria/state/gallery_controller.dart';
import 'package:pictoria/state/review_controller.dart';

import '../support/fake_media_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(GalleryController, ReviewController, FakeMediaRepository)> setUp({
    int items = 5,
    int pageSize = 50,
  }) async {
    final device = FakeMediaRepository(items: fakeDeviceItems(items));
    final gallery = GalleryController(
      deviceRepository: device,
      initialFavorites: {},
      pageSize: pageSize,
    );
    final review = ReviewController(gallery: gallery);
    addTearDown(() {
      review.dispose();
      gallery.dispose();
    });
    await gallery.initialize();
    return (gallery, review, device);
  }

  test('keep and mark advance through the queue in order', () async {
    final (_, review, _) = await setUp();

    expect(review.current?.id, 'device-0');
    expect(review.next?.id, 'device-1');

    review.keep();
    expect(review.current?.id, 'device-1');
    review.markForDeletion();
    expect(review.current?.id, 'device-2');

    expect(review.keptCount, 1);
    expect(review.markedCount, 1);
    expect(review.reviewedCount, 2);
    expect(review.progress, closeTo(2 / 5, 0.001));
    expect(review.markedForDeletion.map((m) => m.id), ['device-1']);
  });

  test('marking never deletes anything from the library', () async {
    final (gallery, review, device) = await setUp();
    final before = List.of(device.items);

    review.markForDeletion();
    review.markForDeletion();

    expect(device.items, before, reason: 'repository untouched');
    expect(gallery.feedFor(MediaTypeFilter.all).items, hasLength(5));
    expect(device.invalidateCount, 0);
  });

  test('undo restores the last card and its decision', () async {
    final (_, review, _) = await setUp();

    review.keep();
    review.markForDeletion();
    expect(review.current?.id, 'device-2');

    final undone = review.undo();
    expect(undone?.item.id, 'device-1');
    expect(undone?.decision, ReviewDecision.delete);
    expect(review.current?.id, 'device-1');
    expect(review.markedCount, 0);

    review.undo();
    expect(review.current?.id, 'device-0');
    expect(review.canUndo, isFalse);
    expect(review.undo(), isNull);
  });

  test('reaching the end leaves no current card', () async {
    final (_, review, _) = await setUp(items: 2);
    review.keep();
    review.keep();
    expect(review.current, isNull);
    expect(review.reviewedCount, 2);
  });

  test('unmark and startOver clear decisions', () async {
    final (_, review, _) = await setUp();
    review.markForDeletion();
    final marked = review.markedForDeletion.single;

    review.unmark(marked);
    expect(review.markedCount, 0);
    expect(review.current?.id, 'device-0');

    review.keep();
    review.markForDeletion();
    review.startOver();
    expect(review.reviewedCount, 0);
    expect(review.canUndo, isFalse);
  });

  test('loads the next page when the queue runs low', () async {
    final (gallery, review, device) = await setUp(items: 25, pageSize: 10);
    expect(gallery.feedFor(MediaTypeFilter.all).items, hasLength(10));

    // Deciding 3 leaves 7 cards (< 8), which triggers a prefetch.
    review
      ..keep()
      ..keep()
      ..keep();
    await pumpEventQueue();

    expect(device.fetchCount, 2);
    expect(review.totalCount, 20);
  });

  test('decisions survive the Gallery switching its filter', () async {
    final (gallery, review, _) = await setUp();
    review.markForDeletion();

    gallery.setTypeFilter(MediaTypeFilter.videos);
    await pumpEventQueue();

    expect(review.markedCount, 1);
    expect(review.current?.id, 'device-1');
  });

  test('switching library source clears undo history', () async {
    final (gallery, review, _) = await setUp();
    review.keep();
    expect(review.canUndo, isTrue);

    gallery.useDemoMedia();
    await pumpEventQueue();

    expect(review.canUndo, isFalse);
    expect(review.current?.isDemo, isTrue);
  });
}
