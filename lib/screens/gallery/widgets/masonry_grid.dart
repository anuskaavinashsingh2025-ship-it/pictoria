import 'package:flutter/material.dart';

import '../../../data/media/media_item.dart';
import '../../../theme/app_tokens.dart';

/// A simple masonry ("Pinterest-style") block of photos.
///
/// Each item goes into whichever column is currently shortest, which keeps
/// the columns roughly even. The number of columns adapts to screen width.
///
/// Long days are split into several blocks so only the visible blocks are
/// built (see GalleryScreen). For blocks in the middle of a day,
/// [equalizeColumns] stretches tiles slightly so every column ends at the
/// same height and the next block joins seamlessly.
class MasonryGrid extends StatelessWidget {
  const MasonryGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.equalizeColumns = false,
  });

  final List<MediaItem> items;
  final bool equalizeColumns;

  /// Builds the tile for [item] at the given size.
  final Widget Function(
    BuildContext context,
    MediaItem item,
    double width,
    double height,
  )
  itemBuilder;

  static const double _gap = AppSpacing.gridGap;

  /// 2 columns on very narrow screens, 3 on phones, more on tablets/desktop.
  static int columnCountFor(double width) {
    if (width < 300) return 2;
    if (width < 560) return 3;
    if (width < 840) return 4;
    return 5;
  }

  /// Tile shapes are clamped so very wide or very tall photos still look tidy:
  /// landscapes become near-square, portraits become a gentle 2:3.
  static double tileAspectRatio(MediaItem item) =>
      item.aspectRatio.clamp(0.66, 1.0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnCountFor(constraints.maxWidth);
        final columnWidth =
            (constraints.maxWidth - _gap * (columns - 1)) / columns;

        // Distribute items into columns, always filling the shortest one.
        final columnItems = List.generate(columns, (_) => <MediaItem>[]);
        final tileHeights = List.generate(columns, (_) => <double>[]);
        final columnHeights = List.filled(columns, 0.0);
        for (final item in items) {
          var shortest = 0;
          for (var c = 1; c < columns; c++) {
            if (columnHeights[c] < columnHeights[shortest]) shortest = c;
          }
          final height = columnWidth / tileAspectRatio(item);
          columnItems[shortest].add(item);
          tileHeights[shortest].add(height);
          columnHeights[shortest] += height + _gap;
        }

        if (equalizeColumns) {
          // Spread each column's shortfall evenly over its tiles. With
          // several tiles per column the stretch is barely noticeable, and
          // photos are cropped to fill, so nothing gets distorted.
          final tallest = columnHeights.reduce((a, b) => a > b ? a : b);
          for (var c = 0; c < columns; c++) {
            final count = tileHeights[c].length;
            if (count == 0) continue;
            final extra = (tallest - columnHeights[c]) / count;
            for (var i = 0; i < count; i++) {
              tileHeights[c][i] += extra;
            }
          }
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) const SizedBox(width: _gap),
              SizedBox(
                width: columnWidth,
                child: Column(
                  children: [
                    for (var i = 0; i < columnItems[c].length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: _gap),
                        child: itemBuilder(
                          context,
                          columnItems[c][i],
                          columnWidth,
                          tileHeights[c][i],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
