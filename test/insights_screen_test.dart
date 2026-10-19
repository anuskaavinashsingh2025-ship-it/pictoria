import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/media/media_access.dart';
import 'package:pictoria/data/media/platform_info.dart';
import 'package:pictoria/data/review/review_store.dart';
import 'package:pictoria/screens/home_shell.dart';

import 'support/fake_media_repository.dart';

const mb = 1000 * 1000;
const gb = 1000 * mb;

/// Opens the Insights tab with a fake library and fake device storage.
Future<FakeMediaRepository> openInsights(
  WidgetTester tester, {
  DeviceStorage? storage = const DeviceStorage(
    totalBytes: 128 * gb,
    availableBytes: 41 * gb,
  ),
  MediaAccess access = MediaAccess.granted,
  Map<String, int> sizes = const {},
}) async {
  tester.view.physicalSize = const Size(400, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final device = FakeMediaRepository(
    access: access,
    items: fakeDeviceItems(5, isVideo: (i) => i < 2),
  )..sizes = sizes;
  await tester.pumpWidget(
    MaterialApp(
      home: HomeShell(
        deviceRepository: device,
        reviewStore: MemoryReviewStore(),
        platformInfo: FakePlatformInfo(storage),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('Insights'));
  await tester.pumpAndSettle();
  return device;
}

void main() {
  testWidgets('storage donut shows real device figures and the breakdown', (
    tester,
  ) async {
    await openInsights(
      tester,
      sizes: {'device-0': 30 * mb, 'device-1': 20 * mb},
    );

    expect(find.text('68%'), findsOneWidget); // 87 of 128 GB used
    expect(find.text('128 GB  total', findRichText: true), findsOneWidget);
    expect(find.bySemanticsLabel('Videos: 50 MB'), findsOneWidget);
    // 3 photos × 2 KB (the fake's default size).
    expect(find.bySemanticsLabel('Photos: 6.1 KB'), findsOneWidget);
    expect(find.bySemanticsLabel('Free: 41 GB'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Other: ')), findsOneWidget);
  });

  testWidgets('without device storage it never shows a fake total', (
    tester,
  ) async {
    await openInsights(tester, storage: null);

    expect(find.textContaining('%'), findsNothing);
    expect(find.text('library'), findsOneWidget);
    expect(
      find.textContaining('Device storage isn’t available'),
      findsOneWidget,
    );
  });

  testWidgets('duplicates are not guessed; no large videos means no reclaim', (
    tester,
  ) async {
    await openInsights(tester);

    expect(find.textContaining('Not available yet'), findsOneWidget);
    expect(find.textContaining('Reclaim up to'), findsNothing);
    expect(find.text('No videos over 100 MB'), findsOneWidget);
  });

  testWidgets('large videos: reclaim estimate, list, and marking', (
    tester,
  ) async {
    await openInsights(
      tester,
      sizes: {'device-0': 300 * mb, 'device-1': 150 * mb},
    );

    expect(find.text('Reclaim up to 450 MB'), findsOneWidget);
    expect(find.text('from 2 large videos (estimate)'), findsOneWidget);
    expect(find.text('2 files · 450 MB'), findsOneWidget);

    await tester.tap(find.text('Reclaim up to 450 MB'));
    await tester.pumpAndSettle();
    expect(find.text('Large videos'), findsOneWidget);
    // Biggest first.
    final first = tester.getTopLeft(find.text('300 MB')).dy;
    final second = tester.getTopLeft(find.text('150 MB')).dy;
    expect(first, lessThan(second));

    await tester.tap(find.text('300 MB'));
    await tester.pumpAndSettle();
    expect(find.text('Marked'), findsOneWidget);
    expect(find.text('Review 1 marked item'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('1 item selected'), findsOneWidget);
    expect(find.text('About 300 MB'), findsOneWidget);
    expect(find.textContaining('Recently Deleted'), findsWidgets);
  });

  testWidgets('Continue to delete opens the existing confirmation flow', (
    tester,
  ) async {
    final device = await openInsights(tester, sizes: {'device-0': 300 * mb});
    await tester.tap(find.text('Reclaim up to 300 MB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('300 MB'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 item?'), findsOneWidget);
    expect(device.deleteCallCount, 0, reason: 'not without Continue');

    // Cancel goes back to the queue, still nothing deleted.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Marked for deletion'), findsOneWidget);
    expect(device.deleteCallCount, 0);
  });

  testWidgets('Review items opens the deletion queue', (tester) async {
    await openInsights(tester, sizes: {'device-0': 300 * mb});
    await tester.tap(find.text('Reclaim up to 300 MB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('300 MB'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review items'));
    await tester.pumpAndSettle();
    expect(find.text('Marked for deletion'), findsOneWidget);
    expect(find.textContaining('1 of 1 selected'), findsOneWidget);
  });

  testWidgets('demo mode explains what is needed instead of measuring', (
    tester,
  ) async {
    await openInsights(tester, access: MediaAccess.notDetermined);

    expect(find.text('Bring in your own photos'), findsOneWidget);
    expect(
      find.text('Connect your photo library to find them'),
      findsOneWidget,
    );
    expect(find.textContaining('Reclaim up to'), findsNothing);
    expect(find.text('68%'), findsOneWidget, reason: 'device storage is real');
  });

  testWidgets('the illustration card is present and labelled', (tester) async {
    await openInsights(tester);
    expect(
      find.bySemanticsLabel('More space for what matters.'),
      findsOneWidget,
    );
  });
}
