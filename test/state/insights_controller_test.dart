import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/media/media_access.dart';
import 'package:pictoria/data/media/media_repository.dart';
import 'package:pictoria/data/media/platform_info.dart';
import 'package:pictoria/state/gallery_controller.dart';
import 'package:pictoria/state/insights_controller.dart';

import '../support/fake_media_repository.dart';

const mb = 1000 * 1000;
const gb = 1000 * mb;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMediaRepository device;
  late GalleryController gallery;
  late InsightsController insights;
  late FakePlatformInfo platform;

  Future<void> setUpWith({
    MediaAccess access = MediaAccess.granted,
    DeviceStorage? storage = const DeviceStorage(
      totalBytes: 128 * gb,
      availableBytes: 41 * gb,
    ),
  }) async {
    // device-0 and device-1 are videos; the rest are photos.
    device =
        FakeMediaRepository(
            access: access,
            items: fakeDeviceItems(5, isVideo: (i) => i < 2),
          )
          ..sizes = {
            'device-0': 300 * mb,
            'device-1': 40 * mb,
            'device-2': 3 * mb,
            'device-3': 2 * mb,
          };
    device.unknownSizeIds = {'device-4'};
    platform = FakePlatformInfo(storage);
    gallery = GalleryController(deviceRepository: device, initialFavorites: {});
    insights = InsightsController(
      gallery: gallery,
      platform: platform,
      pageSize: 2, // several pages, to exercise paging
      concurrency: 2,
    );
    addTearDown(() {
      insights.dispose();
      gallery.dispose();
    });
    await gallery.initialize();
  }

  test('measures real file sizes for photos and videos', () async {
    await setUpWith();
    await insights.refreshIfNeeded();

    final stats = insights.stats;
    expect(insights.status, InsightsStatus.ready);
    expect(stats.videoCount, 2);
    expect(stats.photoCount, 3);
    expect(stats.videoBytes, 340 * mb);
    expect(stats.photoBytes, 5 * mb);
    expect(stats.unknownSizeCount, 1, reason: 'never guessed');
    expect(insights.scannedCount, 5);
  });

  test('large videos are over the threshold, biggest first', () async {
    await setUpWith();
    await insights.refreshIfNeeded();

    final large = insights.stats.largeVideos;
    expect(large.map((v) => v.item.id), ['device-0']);
    expect(insights.stats.largeVideoBytes, 300 * mb);
  });

  test('"everything else" is device-used minus measured media', () async {
    await setUpWith();
    await insights.refreshIfNeeded();

    // used = 128 − 41 = 87 GB; media = 345 MB.
    expect(insights.everythingElseBytes, 87 * gb - 345 * mb);
  });

  test('without device figures there is no fake total', () async {
    await setUpWith(storage: null);
    await insights.refreshIfNeeded();
    await pumpEventQueue();

    expect(insights.storage, isNull);
    expect(insights.storageLoaded, isTrue);
    expect(insights.everythingElseBytes, isNull);
    expect(insights.stats.mediaBytes, 345 * mb);
  });

  test('demo mode and no access skip the scan', () async {
    await setUpWith(access: MediaAccess.notDetermined);
    await insights.refreshIfNeeded();
    expect(insights.status, InsightsStatus.demo);
    expect(device.fileSizeCalls, 0);

    gallery.useDeviceLibrary(); // request → still not granted
    await pumpEventQueue();
    device.access = MediaAccess.denied;
    await insights.scan();
    expect(
      insights.status,
      anyOf(InsightsStatus.demo, InsightsStatus.noAccess),
    );
    expect(device.fileSizeCalls, 0);
  });

  test('reuses a scan until the library changes', () async {
    await setUpWith();
    await insights.refreshIfNeeded();
    final calls = device.fileSizeCalls;

    await insights.refreshIfNeeded();
    expect(device.fileSizeCalls, calls, reason: 'nothing changed');

    await gallery.refresh(); // e.g. after a deletion
    expect(insights.isStale, isTrue);
    await insights.refreshIfNeeded();
    expect(device.fileSizeCalls, calls * 2);
  });

  test('a scan failure shows an error state', () async {
    await setUpWith();
    device.nextFetchError = Exception('library busy');
    await insights.refreshIfNeeded();
    expect(insights.status, InsightsStatus.error);
  });

  test('disposing mid-scan is safe', () async {
    await setUpWith();
    device.fetchGate = Completer<void>();
    final scan = insights.scan();
    await pumpEventQueue();
    insights.dispose();
    device.fetchGate!.complete();
    await expectLater(scan, completes);
    // Re-create so tearDown can dispose something valid.
    insights = InsightsController(gallery: gallery, platform: platform);
  });

  test('sizeOf returns measured sizes for the deletion summary', () async {
    await setUpWith();
    await insights.refreshIfNeeded();
    expect(
      insights.sizeOf(gallery.feedFor(MediaTypeFilter.all).items[2]),
      3 * mb,
    );
  });
}
