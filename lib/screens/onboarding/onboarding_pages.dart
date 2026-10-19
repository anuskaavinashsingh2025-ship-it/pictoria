import 'package:flutter/material.dart';

import '../../data/demo_media.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/doodles.dart';
import 'widgets/photo_collage.dart';

/// The content of one onboarding page.
class OnboardingPageData {
  const OnboardingPageData({
    required this.headline,
    required this.body,
    required this.cards,
    required this.doodles,
  });

  final String headline;
  final String body;
  final List<CollageCardSpec> cards;
  final List<CollageDoodleSpec> doodles;
}

/// The three onboarding pages, all sharing the same visual system.
final onboardingPages = <OnboardingPageData>[
  OnboardingPageData(
    headline: 'Your memories\ndeserve better.',
    body: 'A smarter, kinder way to organize your photos and videos.',
    cards: [
      CollageCardSpec(
        item: demoById('golden_retriever_grass'),
        alignment: const Alignment(0.9, -1),
        widthFactor: 0.46,
        aspectRatio: 0.8,
        angle: 0.07,
      ),
      CollageCardSpec(
        item: demoById('dandelion_golden_hour'),
        alignment: const Alignment(-0.95, 0.62),
        widthFactor: 0.33,
        aspectRatio: 0.74,
        angle: -0.13,
      ),
      CollageCardSpec(
        item: demoById('birds_sunset'),
        alignment: const Alignment(0.92, 0.8),
        widthFactor: 0.4,
        aspectRatio: 0.7,
        angle: 0.08,
      ),
      CollageCardSpec(
        item: demoById('lab_with_tulip'),
        alignment: const Alignment(-0.1, 0.35),
        widthFactor: 0.46,
        aspectRatio: 0.72,
        angle: -0.06,
      ),
    ],
    doodles: const [
      CollageDoodleSpec(
        kind: DoodleKind.heart,
        color: AppColors.rose,
        alignment: Alignment(-0.15, -0.95),
        size: 26,
        angle: -0.2,
      ),
      CollageDoodleSpec(
        kind: DoodleKind.starburst,
        color: AppColors.mint,
        alignment: Alignment(1, -0.05),
        size: 46,
        angle: 0.3,
        onTop: true,
      ),
      CollageDoodleSpec(
        kind: DoodleKind.confetti,
        color: AppColors.primary,
        alignment: Alignment(-0.9, -0.05),
        size: 34,
      ),
      CollageDoodleSpec(
        kind: DoodleKind.ring,
        color: AppColors.lavender,
        alignment: Alignment(0.05, 1.02),
        size: 30,
        angle: 1.2,
      ),
    ],
  ),
  OnboardingPageData(
    headline: 'Find any\nmoment, fast.',
    body:
        'Search by what you remember — “sunset”, “dog”, “Italy” — '
        'and it rises to the top.',
    cards: [
      CollageCardSpec(
        item: demoById('santorini_sunset'),
        alignment: const Alignment(-0.85, -0.9),
        widthFactor: 0.56,
        aspectRatio: 1.35,
        angle: -0.07,
      ),
      CollageCardSpec(
        item: demoById('heart_latte'),
        alignment: const Alignment(-0.9, 0.85),
        widthFactor: 0.36,
        aspectRatio: 0.8,
        angle: 0.09,
      ),
      CollageCardSpec(
        item: demoById('cafe_drinks'),
        alignment: const Alignment(0.95, 0.7),
        widthFactor: 0.36,
        aspectRatio: 0.78,
        angle: -0.1,
      ),
      CollageCardSpec(
        item: demoById('manarola_italy'),
        alignment: const Alignment(0.55, -0.05),
        widthFactor: 0.46,
        aspectRatio: 0.72,
        angle: 0.06,
      ),
    ],
    doodles: const [
      CollageDoodleSpec(
        kind: DoodleKind.sparkle,
        color: AppColors.butter,
        alignment: Alignment(0.95, -0.95),
        size: 30,
      ),
      CollageDoodleSpec(
        kind: DoodleKind.squiggle,
        color: AppColors.primary,
        alignment: Alignment(-0.2, 0.25),
        size: 40,
        angle: -0.4,
        onTop: true,
      ),
      CollageDoodleSpec(
        kind: DoodleKind.starburst,
        color: AppColors.peach,
        alignment: Alignment(0.1, 1),
        size: 38,
      ),
    ],
  ),
  OnboardingPageData(
    headline: 'Keep the best.\nLet go gently.',
    body:
        'Review your library at your own pace. Nothing is ever removed '
        'without your say.',
    cards: [
      CollageCardSpec(
        item: demoById('turquoise_lake'),
        alignment: const Alignment(0.9, -0.95),
        widthFactor: 0.5,
        aspectRatio: 1.3,
        angle: 0.08,
      ),
      CollageCardSpec(
        item: demoById('dog_beach_run'),
        alignment: const Alignment(-0.95, -0.15),
        widthFactor: 0.38,
        aspectRatio: 0.74,
        angle: -0.1,
      ),
      CollageCardSpec(
        item: demoById('sunset_golden_sea'),
        alignment: const Alignment(0.95, 0.9),
        widthFactor: 0.48,
        aspectRatio: 1.2,
        angle: -0.05,
      ),
      CollageCardSpec(
        item: demoById('friends_picnic'),
        alignment: const Alignment(0.05, 0.55),
        widthFactor: 0.42,
        aspectRatio: 0.76,
        angle: 0.05,
        badge: Icons.favorite_rounded,
      ),
    ],
    doodles: const [
      CollageDoodleSpec(
        kind: DoodleKind.heart,
        color: AppColors.rose,
        alignment: Alignment(-0.7, -1),
        size: 28,
        angle: 0.2,
      ),
      CollageDoodleSpec(
        kind: DoodleKind.sparkle,
        color: AppColors.mint,
        alignment: Alignment(-0.85, 0.95),
        size: 32,
      ),
      CollageDoodleSpec(
        kind: DoodleKind.confetti,
        color: AppColors.butter,
        alignment: Alignment(0.95, 0.15),
        size: 34,
        angle: 0.6,
      ),
    ],
  ),
];
