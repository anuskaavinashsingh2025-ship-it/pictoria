import 'package:flutter/material.dart';

import '../../data/media/media_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/brand_wordmark.dart';
import '../../widgets/gradient_cta_button.dart';
import '../../widgets/page_dots.dart';
import '../../widgets/pastel_backdrop.dart';
import '../home_shell.dart';
import 'onboarding_pages.dart';
import 'widgets/photo_collage.dart';

/// A short three-page welcome carousel.
///
/// It never asks for photo permissions; it only introduces the app and then
/// replaces itself with the main [HomeShell].
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.deviceRepository});

  /// Passed through to [HomeShell] (tests use a fake library).
  final MediaRepository? deviceRepository;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLastPage => _page == onboardingPages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLastPage) {
      _openGallery();
      return;
    }
    _controller.nextPage(
      duration: AppDurations.of(context, AppDurations.page),
      curve: AppCurves.emphasized,
    );
  }

  /// Swaps onboarding for the gallery. `pushReplacement` removes onboarding
  /// from the navigation stack, so the back button won't return to it.
  void _openGallery() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: AppDurations.of(context, AppDurations.page),
        pageBuilder: (context, animation, secondaryAnimation) =>
            HomeShell(deviceRepository: widget.deviceRepository),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppCurves.standard,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.97, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        // Rebuilds the backdrop as the page scrolls so shapes drift smoothly.
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.hasClients
              ? (_controller.page ?? 0)
              : 0.0;
          return PastelBackdrop(progress: progress, child: child!);
        },
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(onSkip: _isLastPage ? null : _openGallery),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: onboardingPages.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) =>
                      _OnboardingPage(data: onboardingPages[index]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen + 4,
                  AppSpacing.md,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: Row(
                  children: [
                    PageDots(count: onboardingPages.length, current: _page),
                    const Spacer(),
                    GradientCtaButton(
                      onPressed: _next,
                      label: _isLastPage ? 'Open Gallery' : null,
                      semanticLabel: _isLastPage ? 'Open Gallery' : 'Next',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});

  /// Null on the last page, where Skip is hidden.
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const BrandWordmark(fontSize: 32),
            const Spacer(),
            AnimatedOpacity(
              opacity: onSkip == null ? 0 : 1,
              duration: AppDurations.of(context, AppDurations.medium),
              child: TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  backgroundColor: AppColors.ivory.withValues(alpha: 0.7),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text('Skip', style: AppText.label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    // Big headlines are lovely, but very large text sizes would crowd out the
    // collage, so scaling is capped (it still grows up to 1.3×).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              header: true,
              child: Text(data.headline, style: AppText.display),
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(data.body, style: AppText.body),
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: PhotoCollage(cards: data.cards, doodles: data.doodles),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
