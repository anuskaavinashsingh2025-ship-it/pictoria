import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/media/media_access.dart';
import 'package:pictoria/data/review/review_store.dart';
import 'package:pictoria/screens/home_shell.dart';
import 'package:pictoria/screens/insights/widgets/insight_cards.dart';
import 'package:pictoria/widgets/gradient_cta_button.dart';

import 'support/fake_media_repository.dart';

/// Custom buttons merge their children into one labelled node with
/// `excludeSemantics`, so they must expose the tap action themselves or
/// screen readers can focus them but never activate them.
void expectTapAction(WidgetTester tester, Finder finder) {
  final data = tester.getSemantics(finder).getSemanticsData();
  expect(
    data.hasAction(SemanticsAction.tap),
    isTrue,
    reason: '"${data.label}" has no semantics tap action',
  );
}

/// Activates a button the way VoiceOver / TalkBack do: through its semantics
/// node, not by tapping its position.
Future<void> semanticsTap(WidgetTester tester, Finder finder) async {
  final node = tester.getSemantics(finder);
  node.owner!.performAction(node.id, SemanticsAction.tap);
  await tester.pumpAndSettle();
}

Future<void> pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: HomeShell(
        deviceRepository: FakeMediaRepository(
          access: MediaAccess.granted,
          items: fakeDeviceItems(5),
        ),
        reviewStore: MemoryReviewStore(),
        platformInfo: FakePlatformInfo(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nav bar and Gallery buttons expose a tap action', (
    tester,
  ) async {
    await pumpHome(tester);

    for (final label in ['Gallery', 'Review', 'Insights']) {
      expectTapAction(tester, find.bySemanticsLabel(label));
    }
    expectTapAction(tester, find.bySemanticsLabel('Favorites filter'));
    expectTapAction(
      tester,
      find.bySemanticsLabel(RegExp(r'^Photo: IMG_\d+\.HEIC$')).first,
    );
    expectTapAction(tester, find.bySemanticsLabel('Add to favorites').first);
    expectTapAction(tester, find.bySemanticsLabel('Library settings'));

    // Activating through semantics really runs the action.
    await semanticsTap(tester, find.bySemanticsLabel('Library settings'));
    expectTapAction(tester, find.bySemanticsLabel(RegExp('My photo library')));
    expectTapAction(tester, find.bySemanticsLabel(RegExp('Demo photos')));
  });

  testWidgets('Review buttons expose a tap action', (tester) async {
    await pumpHome(tester);
    await semanticsTap(tester, find.bySemanticsLabel('Review'));

    for (final label in [
      'Keep',
      'Mark for deletion',
      'Close review',
      'Marked for deletion',
    ]) {
      expectTapAction(tester, find.bySemanticsLabel(label));
    }

    expect(find.text('1 of 5'), findsOneWidget);
    await semanticsTap(tester, find.bySemanticsLabel('Keep'));
    expect(find.text('2 of 5'), findsOneWidget);
    expectTapAction(tester, find.bySemanticsLabel('Undo'));
  });

  testWidgets('CTA button and tappable insight cards expose a tap action', (
    tester,
  ) async {
    var ctaTaps = 0;
    var cardTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GradientCtaButton(
                semanticLabel: 'Next',
                onPressed: () => ctaTaps++,
              ),
              InsightCard(
                semanticLabel: 'Large videos',
                onTap: () => cardTaps++,
                child: const Text('Large videos'),
              ),
            ],
          ),
        ),
      ),
    );

    await semanticsTap(tester, find.bySemanticsLabel('Next'));
    await semanticsTap(tester, find.bySemanticsLabel('Large videos'));
    expect(ctaTaps, 1);
    expect(cardTaps, 1);
  });
}
