import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/media/media_repository.dart';
import 'package:pictoria/state/gallery_controller.dart';
import 'package:pictoria/state/review_controller.dart';

import '../support/fake_media_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GalleryController controllerFor(FakeMediaRepository device) {
    final controller = GalleryController(
      deviceRepository: device,
      initialFavorites: {},
      pageSize: 10,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('oldest first is paged by the platform in its own feed', () async {
    final device = FakeMediaRepository(items: fakeDeviceItems(25));
    final gallery = controllerFor(device);
    await gallery.initialize();

    gallery.setOldestFirst(true);
    await pumpEventQueue();
    expect(gallery.feed.items.first.id, 'device-24');
    expect(device.oldestFirstFetches, 1);

    await gallery.loadMore();
    await gallery.loadMore();
    expect(gallery.feed.items, hasLength(25));
    expect(gallery.feed.items.last.id, 'device-0');
    expect(gallery.feed.hasMore, isFalse);

    // The newest-first feed is untouched and still has its single page.
    final newest = gallery.feedFor(MediaTypeFilter.all);
    expect(newest.items.first.id, 'device-0');
    expect(newest.items, hasLength(10));

    gallery.setOldestFirst(false);
    expect(gallery.feed.items.first.id, 'device-0');
  });

  test('loadMore(type:) always pages newest first (used by Review)', () async {
    final device = FakeMediaRepository(items: fakeDeviceItems(15));
    final gallery = controllerFor(device);
    await gallery.initialize();
    gallery.setOldestFirst(true);
    await pumpEventQueue();
    final before = device.oldestFirstFetches;

    await gallery.loadMore(type: MediaTypeFilter.all);

    expect(device.oldestFirstFetches, before);
    expect(gallery.feedFor(MediaTypeFilter.all).items, hasLength(15));
  });

  test('changing the Gallery order does not change the review queue', () async {
    final device = FakeMediaRepository(items: fakeDeviceItems(5));
    final gallery = controllerFor(device);
    final review = ReviewController(gallery: gallery);
    addTearDown(review.dispose);
    await gallery.initialize();
    review.markForDeletion(); // device-0

    gallery.setOldestFirst(true);
    await pumpEventQueue();

    expect(review.current?.id, 'device-1');
    expect(review.markedForDeletion.map((m) => m.id), ['device-0']);
  });
}
