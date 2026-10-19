import 'package:flutter/material.dart';

import '../data/media/device_media_repository.dart';
import '../data/media/media_repository.dart';
import '../data/media/platform_info.dart';
import '../data/review/review_store.dart';
import '../state/gallery_controller.dart';
import '../state/insights_controller.dart';
import '../state/review_controller.dart';
import '../widgets/floating_nav_bar.dart';
import 'gallery/gallery_screen.dart';
import 'insights/insights_screen.dart';
import 'review/review_screen.dart';

/// The main app frame: three tabs plus the floating bottom navigation.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.deviceRepository,
    this.reviewStore,
    this.platformInfo,
  });

  /// Where device media comes from. Tests pass a fake; the app uses the real
  /// photo library by default.
  final MediaRepository? deviceRepository;

  /// Where review decisions are saved. Defaults to on-device storage.
  final ReviewStore? reviewStore;

  /// Native device facts (storage). Tests pass a fake.
  final PlatformInfo? platformInfo;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Created once and kept for the life of the shell, so loaded media
  /// survives tab switches and trips to the viewer.
  late final GalleryController _gallery;

  /// Review decisions live here too, so they survive leaving the tab.
  late final ReviewController _review;
  late final InsightsController _insights;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _gallery = GalleryController(
      deviceRepository: widget.deviceRepository ?? DeviceMediaRepository(),
    );
    // Checks permission silently — it never shows a prompt by itself.
    _gallery.initialize();
    _review = ReviewController(
      gallery: _gallery,
      store: widget.reviewStore ?? SharedPreferencesReviewStore(),
    );
    // Brings back decisions and the deletion queue from the last session.
    _review.restore();
    _insights = InsightsController(
      gallery: _gallery,
      platform: widget.platformInfo,
    );
    // While Insights is open, re-measure when the library changes.
    _gallery.addListener(_refreshInsightsIfVisible);
    // The user may change photo access in Settings while we're in the
    // background, so re-check (cheaply) when the app comes back.
    _lifecycle = AppLifecycleListener(onResume: _gallery.onAppResumed);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _gallery.removeListener(_refreshInsightsIfVisible);
    _insights.dispose();
    _review.dispose();
    _gallery.dispose();
    super.dispose();
  }

  static const _destinations = [
    NavDestination(
      label: 'Gallery',
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library_rounded,
    ),
    NavDestination(
      label: 'Review',
      icon: Icons.swipe_rounded,
      selectedIcon: Icons.swipe_rounded,
    ),
    NavDestination(
      label: 'Insights',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
    ),
  ];

  static const _reviewTab = 1;

  static const _insightsTab = 2;

  void _selectTab(int index) {
    setState(() => _index = index);
    _refreshInsightsIfVisible();
  }

  /// Insights measures the library lazily: only when its tab is showing,
  /// and only again after the library changed.
  void _refreshInsightsIfVisible() {
    if (_index == _insightsTab) _insights.refreshIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final inReview = _index == _reviewTab;
    // Review is a focused, full-screen task (like the design reference):
    // the nav bar hides, and Back or the close button returns to Gallery.
    return PopScope(
      canPop: !inReview,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inReview) _selectTab(0);
      },
      child: Scaffold(
        // Lets content scroll underneath the floating navigation bar.
        extendBody: true,
        // IndexedStack keeps every tab alive, so switching tabs preserves
        // scroll position, search text, filters and review progress.
        body: IndexedStack(
          index: _index,
          children: [
            GalleryScreen(controller: _gallery, insights: _insights),
            // Pause Review's animations while it's hidden behind other tabs.
            TickerMode(
              enabled: inReview,
              child: ReviewScreen(
                controller: _review,
                onClose: () => _selectTab(0),
              ),
            ),
            // Pause Insights' animations (e.g. its measuring spinner) while
            // another tab is showing.
            TickerMode(
              enabled: _index == _insightsTab,
              child: InsightsScreen(insights: _insights, review: _review),
            ),
          ],
        ),
        bottomNavigationBar: inReview
            ? null
            : FloatingNavBar(
                destinations: _destinations,
                selectedIndex: _index,
                onSelected: _selectTab,
              ),
      ),
    );
  }
}
