import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/media/media_access.dart';
import 'package:pictoria/data/review/review_store.dart';
import 'package:pictoria/screens/gallery/widgets/media_tile.dart';
import 'package:pictoria/screens/home_shell.dart';

import 'support/fake_media_repository.dart';

const mb = 1000 * 1000;

/// Six items, newest first: device-0 … device-5. device-0 and device-3 are
/// videos. Sizes are set so each sort gives a distinct order.
Future<FakeMediaRepository> pumpGallery(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final device =
      FakeMediaRepository(
          access: MediaAccess.granted,
          items: fakeDeviceItems(6, isVideo: (i) => i == 0 || i == 3),
        )
        ..sizes = {
          'device-0': 300 * mb, // video
          'device-1': 2 * mb,
          'device-2': 40 * mb,
          'device-3': 15 * mb, // video
          'device-4': 500 * 1000,
        }
        ..unknownSizeIds = {'device-5'};
  await tester.pumpWidget(
    MaterialApp(
      home: HomeShell(
        deviceRepository: device,
        reviewStore: MemoryReviewStore(),
        platformInfo: FakePlatformInfo(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return device;
}

/// Tile ids from top to bottom (tiles in the same row: left to right).
List<String> tileOrder(WidgetTester tester) {
  final tiles = find.byType(MediaTile, skipOffstage: false).evaluate().toList()
    ..sort((a, b) {
      final pa = tester.getTopLeft(find.byWidget(a.widget));
      final pb = tester.getTopLeft(find.byWidget(b.widget));
      final dy = pa.dy.compareTo(pb.dy);
      return dy != 0 ? dy : pa.dx.compareTo(pb.dx);
    });
  return [for (final e in tiles) (e.widget as MediaTile).item.id];
}

Future<void> openFilters(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(RegExp(r'^Filters and sorting')));
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester, String group, String label) async {
  await tester.tap(find.bySemanticsLabel('$group: $label'));
  await tester.pumpAndSettle();
}

Future<void> apply(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Apply filters'));
  await tester.pumpAndSettle();
}

/// Moves the range slider's handles to the given stop indexes (0–9) by
/// calling the slider's own onChanged, exactly as a drag would.
Future<void> setSizeStops(WidgetTester tester, int min, int max) async {
  final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
  slider.onChanged!(RangeValues(min.toDouble(), max.toDouble()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the tune button opens the Filters sheet', (tester) async {
    await pumpGallery(tester);
    await openFilters(tester);

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Media type'), findsOneWidget);
    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('File size'), findsOneWidget);
    expect(find.text('Any size'), findsOneWidget);
  });

  testWidgets('Oldest sorts by date ascending and shows as active', (
    tester,
  ) async {
    final device = await pumpGallery(tester);
    expect(tileOrder(tester).first, 'device-0');

    await openFilters(tester);
    await pick(tester, 'Sort by', 'Oldest');
    await apply(tester);

    expect(tileOrder(tester).first, 'device-5');
    expect(tileOrder(tester).last, 'device-0');
    expect(device.oldestFirstFetches, 1, reason: 'sorted by the platform');
    expect(find.text('Sort: Oldest'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Filters and sorting, 1 active'),
      findsOneWidget,
    );

    // Removing the chip restores newest first.
    await tester.tap(find.bySemanticsLabel('Sort: Oldest. Remove'));
    await tester.pumpAndSettle();
    expect(tileOrder(tester).first, 'device-0');
  });

  testWidgets('Largest groups by size with unknown sizes last', (tester) async {
    await pumpGallery(tester);
    await openFilters(tester);
    await pick(tester, 'Sort by', 'Largest');
    await apply(tester);

    expect(find.text('100 MB – 1 GB'), findsOneWidget);
    expect(find.text('10 MB – 100 MB'), findsOneWidget);
    expect(find.text('1 MB – 10 MB'), findsOneWidget);
    expect(find.text('Under 1 MB'), findsOneWidget);
    expect(find.text('Size unknown'), findsOneWidget);
    final headers = [
      '100 MB – 1 GB',
      '10 MB – 100 MB',
      '1 MB – 10 MB',
      'Under 1 MB',
      'Size unknown',
    ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
    expect(headers, orderedEquals([...headers]..sort()));
  });

  testWidgets('Smallest puts the smallest file first', (tester) async {
    await pumpGallery(tester);
    await openFilters(tester);
    await pick(tester, 'Sort by', 'Smallest');
    await apply(tester);

    expect(tileOrder(tester).first, 'device-4');
    expect(tileOrder(tester).last, 'device-5', reason: 'unknown size last');
  });

  testWidgets('a size range filters by measured size', (tester) async {
    await pumpGallery(tester);
    await openFilters(tester);
    // Stops: 4 = 10 MB, 7 = 500 MB.
    await setSizeStops(tester, 4, 7);
    expect(find.text('10 MB – 500 MB'), findsOneWidget);
    await apply(tester);

    expect(tileOrder(tester).toSet(), {'device-0', 'device-2', 'device-3'});
    expect(find.text('Size: 10 MB – 500 MB'), findsOneWidget);
  });

  testWidgets('type and size combine; impossible filters show No matches', (
    tester,
  ) async {
    await pumpGallery(tester);
    await openFilters(tester);
    await pick(tester, 'Media type', 'Videos');
    await setSizeStops(tester, 4, 7);
    await apply(tester);

    expect(tileOrder(tester).toSet(), {'device-0', 'device-3'});

    await openFilters(tester);
    await setSizeStops(tester, 8, 9); // over 1 GB: nothing that big
    await apply(tester);
    expect(find.text('No matches'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(tileOrder(tester).toSet(), {'device-0', 'device-3'});
  });

  testWidgets('shows progress while sizes are measured', (tester) async {
    final device = await pumpGallery(tester);
    device.fetchGate = Completer<void>();

    await openFilters(tester);
    await pick(tester, 'Sort by', 'Largest');
    await tester.tap(find.bySemanticsLabel('Apply filters'));
    // Not pumpAndSettle: measuring is deliberately still in progress.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Measuring file sizes'), findsOneWidget);
    expect(find.byType(MediaTile), findsNothing);

    device.fetchGate!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Measuring file sizes'), findsNothing);
    expect(tileOrder(tester).first, 'device-0');
  });

  testWidgets('Gallery filters never change the Review queue', (tester) async {
    await pumpGallery(tester);
    await openFilters(tester);
    await pick(tester, 'Sort by', 'Smallest');
    await apply(tester);

    await tester.tap(find.bySemanticsLabel('Review'));
    await tester.pumpAndSettle();
    // Review still starts with the newest item.
    expect(
      find.bySemanticsLabel(RegExp(r'^Video: IMG_0\.HEIC, ')),
      findsOneWidget,
    );
  });
}
