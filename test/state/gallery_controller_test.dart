import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/media/media_access.dart';
import 'package:pictoria/data/media/media_repository.dart';
import 'package:pictoria/state/gallery_controller.dart';

import '../support/fake_media_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GalleryController controllerFor(
    FakeMediaRepository device, {
    int pageSize = 10,
  }) {
    final controller = GalleryController(
      deviceRepository: device,
      initialFavorites: {},
      pageSize: pageSize,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  group('initial access', () {
    test('with access already granted, loads the device library', () async {
      final device = FakeMediaRepository(items: fakeDeviceItems(5));
      final controller = controllerFor(device);

      await controller.initialize();

      expect(controller.source, LibrarySource.device);
      expect(controller.feed.items, hasLength(5));
      expect(device.requestCount, 0, reason: 'never prompts on launch');
    });

    test('when not asked yet, shows demo media and does NOT prompt', () async {
      final device = FakeMediaRepository(access: MediaAccess.notDetermined);
      final controller = controllerFor(device, pageSize: 50);

      await controller.initialize();

      expect(controller.source, LibrarySource.demo);
      expect(controller.feed.items, isNotEmpty);
      expect(device.requestCount, 0);
      expect(device.fetchCount, 0);
    });

    test('initialize only runs once', () async {
      final device = FakeMediaRepository(items: fakeDeviceItems(3));
      final controller = controllerFor(device);
      await controller.initialize();
      await controller.initialize();
      expect(device.checkCount, 1);
      expect(device.fetchCount, 1);
    });

    test('a failing permission check falls back to demo mode', () async {
      final controller = controllerFor(_ThrowingAccessRepository());
      await controller.initialize();
      expect(controller.access, MediaAccess.notDetermined);
      expect(controller.isShowingDemo, isTrue);
    });
  });

  group('connecting the library', () {
    test('granting access switches to the device library', () async {
      final device = FakeMediaRepository(
        access: MediaAccess.notDetermined,
        accessAfterRequest: MediaAccess.granted,
        items: fakeDeviceItems(4),
      );
      final controller = controllerFor(device);
      await controller.initialize();

      await controller.connectLibrary();
      await pumpEventQueue();

      expect(device.requestCount, 1);
      expect(controller.source, LibrarySource.device);
      expect(controller.feed.items.map((m) => m.id), contains('device-0'));
    });

    test('limited access also shows device media', () async {
      final device = FakeMediaRepository(
        access: MediaAccess.notDetermined,
        accessAfterRequest: MediaAccess.limited,
        items: fakeDeviceItems(2),
      );
      final controller = controllerFor(device);
      await controller.initialize();
      await controller.connectLibrary();
      await pumpEventQueue();

      expect(controller.access, MediaAccess.limited);
      expect(controller.feed.items, hasLength(2));
    });

    test('denying keeps demo media and records the state', () async {
      final device = FakeMediaRepository(
        access: MediaAccess.notDetermined,
        accessAfterRequest: MediaAccess.denied,
      );
      final controller = controllerFor(device);
      await controller.initialize();
      await controller.connectLibrary();

      expect(controller.access, MediaAccess.denied);
      expect(controller.isShowingDemo, isTrue);
      expect(controller.feed.items, isNotEmpty);
    });

    test('managing a limited selection reloads the library', () async {
      final device = FakeMediaRepository(
        access: MediaAccess.limited,
        items: fakeDeviceItems(1),
      );
      final controller = controllerFor(device);
      await controller.initialize();

      device.items = fakeDeviceItems(3);
      await controller.manageLimitedSelection();

      expect(device.manageSelectionCount, 1);
      expect(device.invalidateCount, 1);
      expect(controller.feed.items, hasLength(3));
    });
  });

  group('paging', () {
    test('loads pages on demand and stops at the end', () async {
      final device = FakeMediaRepository(items: fakeDeviceItems(25));
      final controller = controllerFor(device, pageSize: 10);
      await controller.initialize();

      expect(controller.feed.items, hasLength(10));
      expect(controller.feed.hasMore, isTrue);

      await controller.loadMore();
      await controller.loadMore();
      expect(controller.feed.items, hasLength(25));
      expect(controller.feed.hasMore, isFalse);

      await controller.loadMore(); // nothing left: no extra request
      expect(device.fetchCount, 3);
    });

    test('ignores duplicate loadMore calls while a page is loading', () async {
      final device = FakeMediaRepository(items: fakeDeviceItems(30));
      final controller = controllerFor(device);
      await controller.initialize();

      device.fetchGate = Completer<void>();
      final first = controller.loadMore();
      final second = controller.loadMore();
      device.fetchGate!.complete();
      await Future.wait([first, second]);

      expect(device.fetchCount, 2); // initial page + exactly one more
    });

    test('each filter keeps its own pages; switching back is free', () async {
      final device = FakeMediaRepository(
        items: fakeDeviceItems(6, isVideo: (i) => i.isOdd),
      );
      final controller = controllerFor(device);
      await controller.initialize();

      controller.setTypeFilter(MediaTypeFilter.videos);
      await pumpEventQueue();
      expect(controller.feed.items.every((m) => m.isVideo), isTrue);
      expect(controller.feed.items, hasLength(3));

      controller.setTypeFilter(MediaTypeFilter.all);
      await pumpEventQueue();
      expect(controller.feed.items, hasLength(6));
      expect(device.fetchCount, 2, reason: 'All was cached, not re-fetched');
    });
  });

  group('errors', () {
    test('a failed page shows an error, and retry recovers', () async {
      final device = FakeMediaRepository(items: fakeDeviceItems(3))
        ..nextFetchError = const MediaLoadException('Library unavailable');
      final controller = controllerFor(device);
      await controller.initialize();

      expect(controller.feed.error, isA<MediaLoadException>());
      expect(controller.feed.items, isEmpty);
      expect(controller.feed.isLoading, isFalse);

      await controller.retry();
      expect(controller.feed.error, isNull);
      expect(controller.feed.items, hasLength(3));
    });
  });

  group('stale results and lifecycle', () {
    test(
      'a slow page from the old source is ignored after switching',
      () async {
        final device = FakeMediaRepository(items: fakeDeviceItems(5))
          ..fetchGate = Completer<void>();
        final controller = controllerFor(device, pageSize: 50);
        final init = controller.initialize();
        await pumpEventQueue();

        controller.useDemoMedia(); // user switches while device page loads
        await pumpEventQueue();
        device.fetchGate!.complete();
        await init;
        await pumpEventQueue();

        expect(controller.isShowingDemo, isTrue);
        expect(controller.feed.items.every((m) => m.isDemo), isTrue);
      },
    );

    test('a result arriving after dispose does not throw', () async {
      final device = FakeMediaRepository(items: fakeDeviceItems(5))
        ..fetchGate = Completer<void>();
      final controller = GalleryController(deviceRepository: device);
      final init = controller.initialize();
      await pumpEventQueue();

      controller.dispose();
      device.fetchGate!.complete();
      await expectLater(init, completes);
    });

    test('resuming with unchanged access does not re-scan', () async {
      final device = FakeMediaRepository(items: fakeDeviceItems(5));
      final controller = controllerFor(device);
      await controller.initialize();

      await controller.onAppResumed();
      expect(device.fetchCount, 1);
    });

    test('resuming after access was revoked falls back to demo', () async {
      final device = FakeMediaRepository(items: fakeDeviceItems(5));
      final controller = controllerFor(device);
      await controller.initialize();

      device.access = MediaAccess.permanentlyDenied;
      await controller.onAppResumed();
      await pumpEventQueue();

      expect(controller.isShowingDemo, isTrue);
      expect(controller.access, MediaAccess.permanentlyDenied);
    });

    test('resuming after access was granted in Settings loads it', () async {
      final device = FakeMediaRepository(
        access: MediaAccess.permanentlyDenied,
        items: fakeDeviceItems(2),
      );
      final controller = controllerFor(device);
      await controller.initialize();

      device.access = MediaAccess.granted;
      await controller.onAppResumed();
      await pumpEventQueue();

      expect(controller.source, LibrarySource.device);
      expect(controller.feed.items, hasLength(2));
    });
  });

  group('favorites', () {
    test('are app-managed and listed newest first', () async {
      final device = FakeMediaRepository(items: fakeDeviceItems(4));
      final controller = controllerFor(device);
      await controller.initialize();

      final items = controller.feed.items;
      controller.toggleFavorite(items[3]);
      controller.toggleFavorite(items[1]);
      expect(controller.favoriteItems.map((m) => m.id), [
        'device-1',
        'device-3',
      ]);

      controller.toggleFavorite(items[1]);
      expect(controller.favoriteItems.map((m) => m.id), ['device-3']);
    });
  });

  test('details are fetched once per item and cached', () async {
    final device = _CountingDetailsRepository(items: fakeDeviceItems(1));
    final controller = controllerFor(device);
    await controller.initialize();
    final item = controller.feed.items.single;

    final a = await controller.detailsFor(item);
    final b = await controller.detailsFor(item);
    expect(a.fileSizeBytes, 2048);
    expect(identical(a, b), isTrue);
    expect(device.detailsCount, 1);
  });
}

class _ThrowingAccessRepository extends FakeMediaRepository {
  @override
  Future<MediaAccess> checkAccess() async =>
      throw UnsupportedError('no photo library on this platform');
}

class _CountingDetailsRepository extends FakeMediaRepository {
  _CountingDetailsRepository({super.items});

  int detailsCount = 0;

  @override
  Future<MediaDetails> loadDetails(item) {
    detailsCount++;
    return super.loadDetails(item);
  }
}
