import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/media/media_access.dart';
import 'package:pictoria/screens/home_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_media_repository.dart';

/// The top review card's accessibility label starts with this.
Finder topCard(int index, {String kind = 'Photo'}) =>
    find.bySemanticsLabel(RegExp('^$kind: IMG_$index\\.HEIC, '));

Finder markedBadge(int count) => find.bySemanticsLabel(
  count == 0 ? 'Marked for deletion' : 'Marked for deletion, $count',
);

Future<FakeMediaRepository> openReview(
  WidgetTester tester, {
  int items = 5,
  bool Function(int)? isVideo,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final device = FakeMediaRepository(
    access: MediaAccess.granted,
    items: fakeDeviceItems(items, isVideo: isVideo),
  );
  await tester.pumpWidget(
    MaterialApp(
      builder: reduceMotion
          ? (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            )
          : null,
      home: HomeShell(deviceRepository: device),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('Review'));
  await tester.pumpAndSettle();
  return device;
}

void main() {
  // Each test starts with empty on-device storage.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the first card, counter and hint', (tester) async {
    await openReview(tester);

    expect(topCard(0), findsOneWidget);
    expect(find.text('1 of 5'), findsOneWidget);
    expect(find.text('KEEP'), findsOneWidget);
    expect(find.text('DELETE'), findsOneWidget);
    expect(find.textContaining('Swipe left to mark'), findsOneWidget);
  });

  testWidgets('swiping right keeps; swiping left only marks', (tester) async {
    final device = await openReview(tester);
    final libraryBefore = List.of(device.items);

    await tester.drag(topCard(0), const Offset(260, 0));
    await tester.pumpAndSettle();
    expect(topCard(1), findsOneWidget);
    expect(find.text('2 of 5'), findsOneWidget);
    expect(markedBadge(0), findsOneWidget);

    await tester.drag(topCard(1), const Offset(-260, 0));
    await tester.pumpAndSettle();
    expect(topCard(2), findsOneWidget);
    expect(markedBadge(1), findsOneWidget);

    expect(device.items, libraryBefore, reason: 'nothing is deleted');
  });

  testWidgets('a short, slow drag springs back', (tester) async {
    await openReview(tester);

    await tester.timedDrag(
      topCard(0),
      const Offset(40, 0),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();

    expect(topCard(0), findsOneWidget);
    expect(find.text('1 of 5'), findsOneWidget);
  });

  testWidgets('buttons are accessible alternatives to swiping', (tester) async {
    await openReview(tester);

    await tester.tap(find.bySemanticsLabel('Keep'));
    await tester.pumpAndSettle();
    expect(topCard(1), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Mark for deletion'));
    await tester.pumpAndSettle();
    expect(topCard(2), findsOneWidget);
    expect(markedBadge(1), findsOneWidget);
  });

  testWidgets('undo brings the last card back', (tester) async {
    await openReview(tester);

    await tester.tap(find.bySemanticsLabel('Mark for deletion'));
    await tester.pumpAndSettle();
    expect(markedBadge(1), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pumpAndSettle();
    expect(topCard(0), findsOneWidget);
    expect(markedBadge(0), findsOneWidget);
    expect(find.text('1 of 5'), findsOneWidget);
  });

  testWidgets('progress is kept when leaving and returning', (tester) async {
    await openReview(tester);

    await tester.tap(find.bySemanticsLabel('Mark for deletion'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close review'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget, reason: 'back in Gallery');

    await tester.tap(find.bySemanticsLabel('Review'));
    await tester.pumpAndSettle();
    expect(topCard(1), findsOneWidget);
    expect(find.text('2 of 5'), findsOneWidget);
    expect(markedBadge(1), findsOneWidget);
  });

  testWidgets('with reduced motion, decisions apply instantly', (tester) async {
    await openReview(tester, reduceMotion: true);

    await tester.tap(find.bySemanticsLabel('Keep'));
    await tester.pump(); // a single frame, no animation to wait for
    expect(topCard(1), findsOneWidget);
  });

  testWidgets('videos show their duration on the card', (tester) async {
    await openReview(tester, isVideo: (i) => i == 0);

    expect(topCard(0, kind: 'Video'), findsOneWidget);
    expect(find.text('0:15'), findsOneWidget);
  });

  testWidgets('finishing shows a summary and makes clear nothing was '
      'deleted', (tester) async {
    await openReview(tester, items: 2);

    await tester.tap(find.bySemanticsLabel('Keep'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Mark for deletion'));
    await tester.pumpAndSettle();

    expect(find.text('All caught up!'), findsOneWidget);
    expect(find.text('Kept 1 · Marked 1 for deletion'), findsOneWidget);
    expect(find.textContaining('Nothing has been deleted'), findsOneWidget);

    await tester.tap(find.text('See marked (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Marked for deletion'), findsOneWidget);

    // Putting an item back returns it to the review queue.
    await tester.tap(find.byTooltip('Put back in review'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing marked for deletion'), findsOneWidget);
  });
}
