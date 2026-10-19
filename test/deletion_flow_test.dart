import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/media/media_access.dart';
import 'package:pictoria/data/media/media_repository.dart';
import 'package:pictoria/data/review/review_store.dart';
import 'package:pictoria/screens/home_shell.dart';

import 'support/fake_media_repository.dart';

/// Opens Review, marks [marks] items with the Delete button, then opens the
/// deletion queue from the badge. All deletion here is simulated.
Future<FakeMediaRepository> openQueue(
  WidgetTester tester, {
  int marks = 2,
  void Function(FakeMediaRepository device)? configure,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final device = FakeMediaRepository(
    access: MediaAccess.granted,
    items: fakeDeviceItems(4),
  );
  configure?.call(device);
  await tester.pumpWidget(
    MaterialApp(
      home: HomeShell(
        deviceRepository: device,
        reviewStore: MemoryReviewStore(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('Review'));
  await tester.pumpAndSettle();
  for (var i = 0; i < marks; i++) {
    await tester.tap(find.bySemanticsLabel('Mark for deletion'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.bySemanticsLabel('Marked for deletion, $marks'));
  await tester.pumpAndSettle();
  return device;
}

Future<void> continueToConfirmation(WidgetTester tester) async {
  await tester.tap(find.textContaining('Review deletion of'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('queue lists marked items with date, type and size', (
    tester,
  ) async {
    await openQueue(tester);

    expect(find.text('Marked for deletion'), findsOneWidget);
    expect(find.text('IMG_0.HEIC'), findsOneWidget);
    expect(find.text('IMG_1.HEIC'), findsOneWidget);
    expect(find.text('Photo · 2.0 KB'), findsNWidgets(2));
    expect(find.text('2 of 2 selected · about 4.1 KB'), findsOneWidget);
    expect(find.text('Review deletion of 2 items'), findsOneWidget);
  });

  testWidgets('deselecting updates the count and size', (tester) async {
    await openQueue(tester);

    await tester.tap(find.text('IMG_0.HEIC'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 selected · about 2.0 KB'), findsOneWidget);
    expect(find.text('Review deletion of 1 item'), findsOneWidget);

    // With one deselected the toggle offers "Select all"; then "none".
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 selected · about 4.1 KB'), findsOneWidget);
    await tester.tap(find.text('Select none'));
    await tester.pumpAndSettle();
    expect(find.text('Select items to delete'), findsOneWidget);
    // The disabled button does nothing: no confirmation screen opens.
    await tester.tap(find.text('Select items to delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete '), findsNothing);
  });

  testWidgets('putting an item back returns it to Review', (tester) async {
    await openQueue(tester);

    await tester.tap(find.byTooltip('Put back in review').first);
    await tester.pumpAndSettle();
    expect(find.text('1 of 1 selected · about 2.0 KB'), findsOneWidget);
  });

  testWidgets('confirmation explains the impact; Cancel deletes nothing', (
    tester,
  ) async {
    final device = await openQueue(tester);
    await continueToConfirmation(tester);

    expect(find.text('Delete 2 items?'), findsOneWidget);
    expect(find.text('Estimated size: about 4.1 KB'), findsOneWidget);
    expect(find.textContaining('Recently Deleted'), findsOneWidget);
    expect(find.textContaining('not just Pictora'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(device.deleteCallCount, 0);
    expect(find.text('2 of 2 selected · about 4.1 KB'), findsOneWidget);
  });

  testWidgets('Continue deletes, reports honestly, and clears the queue', (
    tester,
  ) async {
    final device = await openQueue(tester);
    await continueToConfirmation(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(device.deleteCallCount, 1);
    expect(find.text('Moved 2 items to Recently Deleted'), findsOneWidget);
    expect(find.textContaining('Storage is freed once'), findsOneWidget);
    expect(find.textContaining('was freed'), findsNothing);
    expect(device.items, hasLength(2));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing marked for deletion'), findsOneWidget);
  });

  testWidgets('cancelling the system prompt keeps the items', (tester) async {
    final device = await openQueue(
      tester,
      configure: (d) => d.onDelete = (_) async => [],
    );
    await continueToConfirmation(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing was deleted'), findsOneWidget);
    expect(device.items, hasLength(4));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 selected · about 4.1 KB'), findsOneWidget);
  });

  testWidgets('partial success explains what is left', (tester) async {
    await openQueue(
      tester,
      configure: (d) => d.onDelete = (ids) async => [ids.first],
    );
    await continueToConfirmation(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Deleted 1 of 2 items'), findsOneWidget);
    expect(find.textContaining('still in your queue'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 1 selected · about 2.0 KB'), findsOneWidget);
  });

  testWidgets('a failure keeps everything and says so', (tester) async {
    await openQueue(
      tester,
      configure: (d) => d.deleteError = Exception('platform error'),
    );
    await continueToConfirmation(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 selected · about 4.1 KB'), findsOneWidget);
  });

  testWidgets('permanent deletion is worded as permanent', (tester) async {
    await openQueue(tester, configure: (d) => d.mode = DeletionMode.permanent);
    await continueToConfirmation(tester);
    expect(find.textContaining('permanently deleted'), findsOneWidget);
    expect(find.textContaining('can’t be undone'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Deleted 2 items'), findsOneWidget);
    expect(find.text('About 4.1 KB of storage was freed.'), findsOneWidget);
  });

  testWidgets('items already gone are explained and removed', (tester) async {
    await openQueue(tester, configure: (d) => d.missingIds = {'device-1'});

    expect(
      find.textContaining('already gone from your device'),
      findsOneWidget,
    );
    expect(find.text('IMG_1.HEIC'), findsNothing);
    expect(find.text('1 of 1 selected · about 2.0 KB'), findsOneWidget);
  });
}
