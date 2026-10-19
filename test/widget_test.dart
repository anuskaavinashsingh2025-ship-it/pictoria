import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pictoria/app.dart';
import 'package:pictoria/data/demo_media.dart';
import 'package:pictoria/data/media/media_access.dart';
import 'package:pictoria/data/media/media_repository.dart';
import 'package:pictoria/screens/gallery/gallery_screen.dart';
import 'package:pictoria/screens/gallery/widgets/gallery_states.dart';
import 'package:pictoria/screens/gallery/widgets/media_tile.dart';
import 'package:pictoria/screens/home_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_media_repository.dart';

/// Uses a tall phone-sized surface so every lazily built block is on screen.
void useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpGallery(
  WidgetTester tester,
  FakeMediaRepository device,
) async {
  useTallPhone(tester);
  await tester.pumpWidget(
    MaterialApp(home: HomeShell(deviceRepository: device)),
  );
  await tester.pumpAndSettle();
}

/// Filter chips scroll horizontally on phones, so scroll one into view first.
Future<void> tapFilter(WidgetTester tester, String label) async {
  final chip = find.bySemanticsLabel('$label filter');
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

int tileCount() =>
    find.byType(MediaTile, skipOffstage: false).evaluate().length;

void main() {
  // Each test starts with empty on-device storage.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Onboarding', () {
    testWidgets('Next walks through the pages and opens the Gallery', (
      tester,
    ) async {
      final device = FakeMediaRepository(access: MediaAccess.notDetermined);
      await tester.pumpWidget(PictoraApp(deviceRepository: device));
      expect(find.text('Your memories\ndeserve better.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Find any\nmoment, fast.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Keep the best.\nLet go gently.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Open Gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryScreen), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('never asks for photo permission', (tester) async {
      final device = FakeMediaRepository(access: MediaAccess.notDetermined);
      await tester.pumpWidget(PictoraApp(deviceRepository: device));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.byType(GalleryScreen), findsOneWidget);
      expect(device.requestCount, 0);
    });
  });

  group('Permission states', () {
    testWidgets('not asked yet: demo photos plus a Connect prompt', (
      tester,
    ) async {
      final device = FakeMediaRepository(
        access: MediaAccess.notDetermined,
        accessAfterRequest: MediaAccess.granted,
        items: fakeDeviceItems(4),
      );
      await pumpGallery(tester, device);

      expect(tileCount(), demoPhotos.length);
      expect(find.text('Bring in your own photos'), findsOneWidget);
      expect(device.requestCount, 0);

      await tester.tap(find.text('Connect library'));
      await tester.pumpAndSettle();

      expect(device.requestCount, 1);
      expect(tileCount(), 4);
      expect(find.text('Bring in your own photos'), findsNothing);
    });

    testWidgets('denied: offers Try again and Open Settings', (tester) async {
      final device = FakeMediaRepository(access: MediaAccess.denied);
      await pumpGallery(tester, device);

      expect(find.text('Photo access is off'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Open Settings'));
      expect(device.openSettingsCount, 1);
      expect(tileCount(), demoPhotos.length, reason: 'never blank');
    });

    testWidgets('permanently denied: only Settings can help', (tester) async {
      final device = FakeMediaRepository(access: MediaAccess.permanentlyDenied);
      await pumpGallery(tester, device);

      expect(find.text('Photo access is off'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      await tester.tap(find.text('Open Settings'));
      expect(device.openSettingsCount, 1);
    });

    testWidgets('restricted: explains and keeps demo photos', (tester) async {
      final device = FakeMediaRepository(access: MediaAccess.restricted);
      await pumpGallery(tester, device);

      expect(find.text('Photo access is restricted'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(tileCount(), demoPhotos.length);
    });

    testWidgets('limited: device photos plus Manage selection', (tester) async {
      final device = FakeMediaRepository(
        access: MediaAccess.limited,
        items: fakeDeviceItems(3),
      );
      await pumpGallery(tester, device);

      expect(tileCount(), 3);
      expect(find.text('Showing selected photos'), findsOneWidget);
      await tester.tap(find.text('Manage selection'));
      await tester.pumpAndSettle();
      expect(device.manageSelectionCount, 1);
    });

    testWidgets('granted: device photos and no banner', (tester) async {
      final device = FakeMediaRepository(items: fakeDeviceItems(5));
      await pumpGallery(tester, device);

      expect(tileCount(), 5);
      expect(find.text('Today'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('Loading, error and empty states', () {
    testWidgets('shows a skeleton while the first page loads', (tester) async {
      final device = FakeMediaRepository(items: fakeDeviceItems(3))
        ..fetchGate = Completer<void>();
      useTallPhone(tester);
      await tester.pumpWidget(
        MaterialApp(home: HomeShell(deviceRepository: device)),
      );
      await tester.pump();

      expect(find.byType(GalleryLoadingSkeleton), findsOneWidget);
      expect(tileCount(), 0);

      device.fetchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(GalleryLoadingSkeleton), findsNothing);
      expect(tileCount(), 3);
    });

    testWidgets('shows an error with Try again, which recovers', (
      tester,
    ) async {
      final device = FakeMediaRepository(items: fakeDeviceItems(2))
        ..nextFetchError = const MediaLoadException('Library is busy.');
      await pumpGallery(tester, device);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Library is busy.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(tileCount(), 2);
    });

    testWidgets('empty device library offers demo photos', (tester) async {
      final device = FakeMediaRepository(items: []);
      await pumpGallery(tester, device);

      expect(find.text('Your library is empty'), findsOneWidget);
      await tester.tap(find.text('Show demo photos'));
      await tester.pumpAndSettle();
      expect(tileCount(), demoPhotos.length);
      expect(find.text('Showing demo photos'), findsOneWidget);
    });
  });

  group('Gallery', () {
    testWidgets('filters narrow the grid', (tester) async {
      final device = FakeMediaRepository(
        items: fakeDeviceItems(9, isVideo: (i) => i % 3 == 0),
      );
      await pumpGallery(tester, device);
      expect(tileCount(), 9);

      await tapFilter(tester, 'Videos');
      expect(tileCount(), 3);

      await tapFilter(tester, 'Photos');
      expect(tileCount(), 6);

      await tapFilter(tester, 'Favorites');
      expect(tileCount(), 0);
      expect(find.text('No favorites yet'), findsOneWidget);
    });

    testWidgets('toggling a heart adds it to Pictora favorites', (
      tester,
    ) async {
      final device = FakeMediaRepository(items: fakeDeviceItems(4));
      await pumpGallery(tester, device);

      await tester.tap(find.bySemanticsLabel('Add to favorites').first);
      await tester.pump();
      await tapFilter(tester, 'Favorites');
      expect(tileCount(), 1);
    });

    testWidgets('search matches demo titles and tags', (tester) async {
      final device = FakeMediaRepository(access: MediaAccess.notDetermined);
      await pumpGallery(tester, device);

      await tester.enterText(find.byType(TextField), 'dog');
      await tester.pumpAndSettle();
      final dogs = demoPhotos.where(
        (p) => p.title.toLowerCase().contains('dog') || p.tags.contains('dog'),
      );
      expect(tileCount(), dogs.length);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(tileCount(), 0);
      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('bottom navigation switches tabs and keeps loaded media', (
      tester,
    ) async {
      final device = FakeMediaRepository(items: fakeDeviceItems(5));
      await pumpGallery(tester, device);

      await tester.tap(find.bySemanticsLabel('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('Insights'), findsWidgets);
      // Insights measures the library once (one page for 5 items).
      expect(device.fetchCount, 2);

      await tester.tap(find.bySemanticsLabel('Review'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Swipe left to mark'), findsOneWidget);
      // Review is full-screen: the nav bar hides and Close returns.
      await tester.tap(find.bySemanticsLabel('Close review'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);

      // Coming back to Insights reuses the measurement.
      await tester.tap(find.bySemanticsLabel('Insights'));
      await tester.pumpAndSettle();
      expect(device.fetchCount, 2, reason: 'no re-scan on tab switch');
    });

    testWidgets('opening the viewer shows lazily loaded details', (
      tester,
    ) async {
      final device = FakeMediaRepository(items: fakeDeviceItems(2));
      await pumpGallery(tester, device);

      await tester.tap(find.bySemanticsLabel(RegExp(r'^Photo: IMG_0')).first);
      await tester.pumpAndSettle();
      expect(find.text('IMG_0.HEIC'), findsOneWidget);
      expect(find.textContaining('image/heic · 2.0 KB'), findsOneWidget);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(device.fetchCount, 1, reason: 'no re-scan after the viewer');
    });

    testWidgets('library sheet switches between device and demo', (
      tester,
    ) async {
      final device = FakeMediaRepository(items: fakeDeviceItems(3));
      await pumpGallery(tester, device);

      await tester.tap(find.bySemanticsLabel('Library settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo photos'));
      await tester.pumpAndSettle();
      expect(tileCount(), demoPhotos.length);

      await tester.tap(find.text('Show my library'));
      await tester.pumpAndSettle();
      expect(tileCount(), 3);
    });
  });
}
