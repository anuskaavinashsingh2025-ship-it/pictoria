import 'package:flutter/material.dart';

import '../../data/media/media_access.dart';
import '../../data/media/media_filters.dart';
import '../../data/media/media_item.dart';
import '../../data/media/media_repository.dart';
import '../../state/gallery_controller.dart';
import '../../state/insights_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/brand_wordmark.dart';
import '../../widgets/doodles.dart';
import 'media_viewer_screen.dart';
import 'widgets/filter_chips.dart';
import 'widgets/gallery_filters_sheet.dart';
import 'widgets/gallery_search_bar.dart';
import 'widgets/gallery_states.dart';
import 'widgets/library_access_banner.dart';
import 'widgets/library_source_sheet.dart';
import 'widgets/masonry_grid.dart';
import 'widgets/media_tile.dart';

/// The main Gallery tab: header, search, filters and date-grouped media.
///
/// All loading and permission logic lives in [GalleryController]; this
/// widget only decides what to draw for the controller's current state.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    required this.controller,
    required this.insights,
  });

  final GalleryController controller;

  /// Supplies measured file sizes for size sorting and filtering (the same
  /// measurement the Insights tab uses).
  final InsightsController insights;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _searchController = TextEditingController();
  GalleryFilter _filter = GalleryFilter.all;
  String _query = '';

  /// Sort order and file-size range from the Filters sheet.
  GalleryOptions _options = GalleryOptions.defaults;

  /// Long days are split into blocks of this many items, so only the blocks
  /// near the screen are built (and only their thumbnails requested).
  static const _chunkSize = 24;

  /// Start loading the next page when this close (in pixels) to the end.
  static const _loadMoreThreshold = 1500.0;

  GalleryController get _controller => widget.controller;
  InsightsController get _insights => widget.insights;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectFilter(GalleryFilter filter) {
    setState(() => _filter = filter);
    _controller.setTypeFilter(filter.typeFilter);
  }

  void _openViewer(MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            MediaViewerScreen(item: item, controller: _controller),
      ),
    );
  }

  /// Applies sort and size options.
  ///
  /// Newest/oldest with no size range is sorted by the platform, page by
  /// page. Anything size-based needs every item's size, so it uses the
  /// fully measured library instead of a single page.
  void _applyOptions(GalleryOptions options) {
    setState(() => _options = options);
    _controller.setOldestFirst(
      options.sort == GallerySort.oldest && !options.needsSizes,
    );
    if (options.needsSizes) _insights.ensureMeasured();
  }

  Future<void> _openFilters() async {
    final choice = await showGalleryFiltersSheet(
      context,
      type: _filter.typeFilter,
      options: _options,
    );
    if (choice == null || !mounted) return;
    final filter = switch (choice.type) {
      // "All" keeps the Favorites chip if it was selected.
      MediaTypeFilter.all =>
        _filter == GalleryFilter.favorites
            ? GalleryFilter.favorites
            : GalleryFilter.all,
      MediaTypeFilter.photos => GalleryFilter.photos,
      MediaTypeFilter.videos => GalleryFilter.videos,
    };
    _selectFilter(filter);
    _applyOptions(choice.options);
  }

  void _clearOptions() => _applyOptions(GalleryOptions.defaults);

  int? _sizeOf(MediaItem item) => _insights.sizeOf(item);

  bool _onScroll(ScrollNotification notification) {
    if (!_options.needsSizes &&
        _filter != GalleryFilter.favorites &&
        notification.metrics.extentAfter < _loadMoreThreshold) {
      _controller.loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds whenever the controller reports new data or a new state.
    final content = ListenableBuilder(
      listenable: Listenable.merge([_controller, _insights]),
      builder: (context, _) => _buildScrollView(context),
    );

    // A soft cream strip behind the status bar keeps the clock readable
    // when photos scroll underneath it.
    return Stack(
      children: [
        content,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.paddingOf(context).top,
          child: ColoredBox(color: AppColors.cream.withValues(alpha: 0.94)),
        ),
      ],
    );
  }

  Widget _buildScrollView(BuildContext context) {
    final feed = _controller.feed;
    final showingFavorites = _filter == GalleryFilter.favorites;
    final sized = _options.needsSizes;

    // Size options work on the whole measured library; date options on the
    // platform-sorted pages.
    final List<MediaItem> source;
    if (sized) {
      source = _insights.allItems;
      _scheduleMeasureIfNeeded();
    } else {
      source = showingFavorites ? _controller.favoriteItems : feed.items;
    }
    var visible = filterMedia(
      source,
      filter: _filter,
      query: _query,
      favorites: _controller.favorites,
    );
    if (sized) {
      visible = sortMedia(
        filterBySize(visible, _options.size, _sizeOf),
        _options.sort,
        _sizeOf,
      );
    } else if (showingFavorites && _options.sort == GallerySort.oldest) {
      // Favorites aren't paged, so order them here.
      visible = sortMedia(visible, GallerySort.oldest, _sizeOf);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: _controller.refresh,
        color: AppColors.primary,
        backgroundColor: AppColors.ivory,
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: CustomScrollView(
          // Pull-to-refresh needs the list to be scrollable even when short.
          physics: const AlwaysScrollableScrollPhysics(),
          // Lets the keyboard close when the user starts scrolling the grid.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: _GalleryHeader(
                  onProfileTap: () =>
                      showLibrarySourceSheet(context, _controller),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.lg,
                ),
                child: GallerySearchBar(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  onOptionsPressed: _openFilters,
                  activeFilterCount: _options.activeCount,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FilterChipsRow(
                selected: _filter,
                onSelected: _selectFilter,
              ),
            ),
            SliverToBoxAdapter(
              child: ActiveFiltersRow(
                options: _options,
                onChanged: _applyOptions,
              ),
            ),
            SliverToBoxAdapter(
              child: LibraryAccessBanner(controller: _controller),
            ),
            ..._buildBody(feed, visible, showingFavorites),
            // Space so the last photos can scroll above the floating nav bar.
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
      ),
    );
  }

  /// Measures the library (once per library version) when a size option is
  /// on. Scheduled after the frame because measuring notifies listeners.
  void _scheduleMeasureIfNeeded() {
    if (_insights.sizesReady ||
        _insights.isMeasuring ||
        _insights.measureFailed) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _options.needsSizes) _insights.ensureMeasured();
    });
  }

  /// Slivers for size-based results: progress, error, empty or content.
  List<Widget> _buildSizedBody(List<MediaItem> visible) {
    if (_controller.isCheckingAccess) {
      return const [SliverToBoxAdapter(child: GalleryLoadingSkeleton())];
    }
    if (_insights.measureFailed) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: GalleryMessage(
            title: 'Couldn’t measure file sizes',
            message:
                'Size sorting and filters need each file’s size. Please try '
                'again, or clear the size options.',
            doodle: DoodleKind.squiggle,
            actionLabel: 'Try again',
            onAction: _insights.scan,
            secondaryLabel: 'Clear filters',
            onSecondary: _clearOptions,
          ),
        ),
      ];
    }
    if (!_insights.sizesReady) {
      final expected = _insights.expectedCount;
      final progress = expected == null
          ? '${_insights.scannedCount} items'
          : '${_insights.scannedCount} of $expected items';
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.xl,
              AppSpacing.screen,
              0,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Measuring file sizes… $progress',
                style: AppText.caption,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: GalleryLoadingSkeleton()),
      ];
    }
    if (visible.isEmpty) {
      return [SliverFillRemaining(hasScrollBody: false, child: _noMatches())];
    }
    final groups = _options.sort.isSizeBased
        ? groupBySize(visible, _sizeOf)
        : groupByDay(visible);
    return [_entriesSliver(groups)];
  }

  Widget _noMatches() {
    final kind = switch (_filter) {
      GalleryFilter.photos => 'photos',
      GalleryFilter.videos => 'videos',
      GalleryFilter.favorites => 'favorites',
      GalleryFilter.all => 'photos or videos',
    };
    final size = _options.size.isActive
        ? ' ${_options.size.label.toLowerCase()}'
        : '';
    return GalleryMessage(
      title: 'No matches',
      message: 'No $kind$size match these filters.',
      actionLabel: 'Clear filters',
      onAction: _clearOptions,
    );
  }

  Widget _entriesSliver(List<MediaDayGroup> groups) {
    final entries = _buildEntries(groups);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      // SliverList builds entries lazily: a block of photos is only created
      // (and its thumbnails only requested) when it scrolls near the screen.
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) => _buildEntry(entries[index]),
      ),
    );
  }

  /// Picks the right slivers for loading, error, empty or content states.
  List<Widget> _buildBody(
    MediaFeed feed,
    List<MediaItem> visible,
    bool showingFavorites,
  ) {
    if (_options.needsSizes) return _buildSizedBody(visible);

    final waitingForFirstPage =
        !showingFavorites && feed.isInitialLoad && feed.error == null;
    if (_controller.isCheckingAccess || waitingForFirstPage) {
      return const [SliverToBoxAdapter(child: GalleryLoadingSkeleton())];
    }

    if (!showingFavorites && feed.items.isEmpty && feed.error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: GalleryMessage(
            title: 'Something went wrong',
            message: _errorMessage(feed.error!),
            doodle: DoodleKind.squiggle,
            actionLabel: 'Try again',
            onAction: _controller.retry,
          ),
        ),
      ];
    }

    if (visible.isEmpty) {
      return [
        SliverFillRemaining(hasScrollBody: false, child: _emptyStateFor(feed)),
      ];
    }

    return [
      _entriesSliver(groupByDay(visible)),
      if (!showingFavorites)
        SliverToBoxAdapter(
          child: LoadMoreFooter(
            isLoading: feed.isLoading,
            hasError: feed.error != null,
            onRetry: _controller.retry,
          ),
        ),
    ];
  }

  Widget _emptyStateFor(MediaFeed feed) {
    if (!_options.isDefault && feed.items.isNotEmpty) return _noMatches();
    final query = _query.trim();
    if (query.isNotEmpty) {
      return GalleryMessage(
        title: 'No matches',
        message: 'No memories match “$query”. Try a date, “video” or “photo”.',
      );
    }
    if (_filter == GalleryFilter.favorites) {
      return const GalleryMessage(
        title: 'No favorites yet',
        message:
            'Tap the heart on any photo to keep it here. Pictora favorites '
            'are separate from favorites in your Photos app.',
        doodle: DoodleKind.heart,
      );
    }
    if (!_controller.isShowingDemo && _filter == GalleryFilter.all) {
      final limited = _controller.access == MediaAccess.limited;
      return GalleryMessage(
        title: limited ? 'No photos shared yet' : 'Your library is empty',
        message: limited
            ? 'Choose which photos and videos Pictora can see.'
            : 'Photos and videos you take will appear here. In the meantime, '
                  'you can explore the demo photos.',
        actionLabel: limited ? 'Choose photos' : 'Show demo photos',
        onAction: limited
            ? _controller.manageLimitedSelection
            : _controller.useDemoMedia,
        secondaryLabel: limited ? 'Show demo photos' : null,
        onSecondary: limited ? _controller.useDemoMedia : null,
      );
    }
    return GalleryMessage(
      title: _filter == GalleryFilter.videos ? 'No videos' : 'No photos',
      message: _filter == GalleryFilter.videos
          ? 'Videos in your library will show up here.'
          : 'Photos in your library will show up here.',
    );
  }

  String _errorMessage(Object error) => error is MediaLoadException
      ? error.message
      : "We couldn't load your photos. Please try again.";

  /// Flattens day groups into header + photo-block entries for the lazy list.
  List<_GalleryEntry> _buildEntries(List<MediaDayGroup> groups) {
    final entries = <_GalleryEntry>[];
    for (final group in groups) {
      entries.add(_GalleryEntry.header(group));
      for (var start = 0; start < group.items.length; start += _chunkSize) {
        final end = (start + _chunkSize).clamp(0, group.items.length);
        entries.add(
          _GalleryEntry.block(
            group.items.sublist(start, end),
            // Middle blocks are evened out so the next block joins neatly;
            // the last block of a day keeps its natural masonry edge.
            isLastOfDay: end == group.items.length,
          ),
        );
      }
    }
    return entries;
  }

  Widget _buildEntry(_GalleryEntry entry) {
    final group = entry.group;
    if (group != null) return _DayHeader(group: group);

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return MasonryGrid(
      items: entry.items,
      equalizeColumns: !entry.isLastOfDay,
      itemBuilder: (context, item, width, height) => MediaTile(
        key: ValueKey(item.id),
        item: item,
        image: _controller.thumbnailFor(
          item,
          pixelWidth: (width * pixelRatio).round(),
        ),
        width: width,
        height: height,
        isFavorite: _controller.isFavorite(item),
        onTap: () => _openViewer(item),
        onFavoriteToggle: () => _controller.toggleFavorite(item),
      ),
    );
  }
}

/// One row of the lazy list: either a day header or a block of photos.
class _GalleryEntry {
  _GalleryEntry.header(MediaDayGroup this.group)
    : items = const [],
      isLastOfDay = true;

  _GalleryEntry.block(this.items, {required this.isLastOfDay}) : group = null;

  final MediaDayGroup? group;
  final List<MediaItem> items;
  final bool isLastOfDay;
}

class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader({required this.onProfileTap});

  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        0,
      ),
      child: Row(
        children: [
          const BrandWordmark(),
          const Spacer(),
          Semantics(
            label: 'Library settings',
            button: true,
            onTap: onProfileTap,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onProfileTap,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.peachSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.peach, width: 2),
                ),
                child: const Icon(
                  Icons.face_3_rounded,
                  color: AppColors.ink,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group});

  final MediaDayGroup group;

  @override
  Widget build(BuildContext context) {
    final count = group.items.length;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(group.label, style: AppText.sectionTitle),
            ),
          ),
          Text(
            '$count ${count == 1 ? 'item' : 'items'}',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}
