/// Pure helper functions for sorting, filtering, grouping and formatting
/// media. They have no Flutter or device dependencies, which makes them easy
/// to unit-test.
library;

import 'media_item.dart';
import 'media_repository.dart';

/// The quick filters shown above the grid.
enum GalleryFilter {
  all('All'),
  photos('Photos'),
  videos('Videos'),

  /// Pictora's own favorites (not the system Photos app's favorites).
  favorites('Favorites');

  const GalleryFilter(this.label);

  final String label;

  /// Which page type to request from the repository for this filter.
  MediaTypeFilter get typeFilter => switch (this) {
    GalleryFilter.photos => MediaTypeFilter.photos,
    GalleryFilter.videos => MediaTypeFilter.videos,
    _ => MediaTypeFilter.all,
  };
}

/// Newest first; items without a date go last.
List<MediaItem> sortNewestFirst(Iterable<MediaItem> items) {
  final sorted = items.toList();
  sorted.sort((a, b) {
    final aDate = a.createdAt;
    final bDate = b.createdAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });
  return sorted;
}

/// Appends [page] to [existing], skipping ids already present. Libraries can
/// change between page requests, which may shift items onto the next page.
List<MediaItem> mergeById(List<MediaItem> existing, List<MediaItem> page) {
  final seen = {for (final item in existing) item.id};
  return [
    ...existing,
    for (final item in page)
      if (seen.add(item.id)) item,
  ];
}

/// Applies the chip filter and search text to [items].
List<MediaItem> filterMedia(
  List<MediaItem> items, {
  required GalleryFilter filter,
  String query = '',
  Set<String> favorites = const {},
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  return [
    for (final item in items)
      if (_passes(item, filter, favorites) && matchesQuery(item, query, today))
        item,
  ];
}

bool _passes(MediaItem item, GalleryFilter filter, Set<String> favorites) {
  return switch (filter) {
    GalleryFilter.all => true,
    GalleryFilter.photos => !item.isVideo,
    GalleryFilter.videos => item.isVideo,
    GalleryFilter.favorites => favorites.contains(item.id),
  };
}

/// Simple on-device search: matches the title, tags, kind ("video"),
/// file type, and date words such as "yesterday", "october" or "2025".
bool matchesQuery(MediaItem item, String query, DateTime today) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;

  final created = item.createdAt;
  final haystack = <String>[
    if (item.title != null) item.title!,
    ...item.tags,
    item.isVideo ? 'video' : 'photo',
    if (item.mimeType != null) item.mimeType!,
    if (created != null) ...[
      dayLabel(created, today),
      _months[created.month - 1],
      '${created.year}',
    ],
  ];
  return haystack.any((text) => text.toLowerCase().contains(q));
}

/// A group of items captured on the same calendar day.
class MediaDayGroup {
  const MediaDayGroup({required this.label, required this.items});

  final String label;
  final List<MediaItem> items;
}

/// Groups [items] (sorted newest first) into day sections.
List<MediaDayGroup> groupByDay(List<MediaItem> items, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final groups = <MediaDayGroup>[];
  DateTime? currentDay;
  var started = false;

  for (final item in items) {
    final created = item.createdAt;
    final day = created == null
        ? null
        : DateTime(created.year, created.month, created.day);
    if (!started || day != currentDay) {
      started = true;
      currentDay = day;
      groups.add(
        MediaDayGroup(
          label: day == null ? 'Undated' : dayLabel(day, today),
          items: [],
        ),
      );
    }
    groups.last.items.add(item);
  }
  return groups;
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Today", "Yesterday", a weekday for the past week, "12 October" for this
/// year, or "12 October 2024" for older dates.
String dayLabel(DateTime date, DateTime today) {
  final day = DateTime(date.year, date.month, date.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  // Count whole calendar days (avoids daylight-saving surprises).
  final daysAgo = DateTime.utc(
    todayDay.year,
    todayDay.month,
    todayDay.day,
  ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;

  if (daysAgo == 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';
  if (daysAgo > 1 && daysAgo < 7) return _weekdays[day.weekday - 1];
  final base = '${day.day} ${_months[day.month - 1]}';
  return day.year == todayDay.year ? base : '$base ${day.year}';
}

/// Formats a duration as m:ss (or h:mm:ss), e.g. 0:24.
String formatDuration(Duration d) {
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$minutes:$seconds';
  }
  return '${d.inMinutes}:$seconds';
}

/// Formats bytes as a short human size, e.g. "2.4 MB".
///
/// Uses decimal units (1 KB = 1000 bytes), the same as iOS and Android show
/// in Settings, so Pictora's numbers match the system's.
String formatFileSize(int bytes) {
  if (bytes < 1000) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
}

// -----------------------------------------------------------------------------
// Sorting and file-size filters
// -----------------------------------------------------------------------------

enum GallerySort {
  newest('Newest'),
  oldest('Oldest'),
  largest('Largest'),
  smallest('Smallest');

  const GallerySort(this.label);

  final String label;

  /// Size sorts need every item's measured file size.
  bool get isSizeBased =>
      this == GallerySort.largest || this == GallerySort.smallest;
}

/// A file-size range; null bounds mean "no limit".
class SizeRange {
  const SizeRange({this.minBytes, this.maxBytes});

  static const any = SizeRange();

  final int? minBytes;
  final int? maxBytes;

  bool get isActive => minBytes != null || maxBytes != null;

  bool contains(int bytes) =>
      (minBytes == null || bytes >= minBytes!) &&
      (maxBytes == null || bytes <= maxBytes!);

  /// e.g. "1 MB – 10 MB", "Over 10 MB", "Under 1 MB", "Any size".
  String get label {
    final min = minBytes;
    final max = maxBytes;
    if (min == null && max == null) return 'Any size';
    if (min == null) return 'Under ${formatFileSize(max!)}';
    if (max == null) return 'Over ${formatFileSize(min)}';
    return '${formatFileSize(min)} – ${formatFileSize(max)}';
  }

  @override
  bool operator ==(Object other) =>
      other is SizeRange &&
      other.minBytes == minBytes &&
      other.maxBytes == maxBytes;

  @override
  int get hashCode => Object.hash(minBytes, maxBytes);
}

/// Everything the Filters sheet controls (besides the Favorites chip).
class GalleryOptions {
  const GalleryOptions({
    this.sort = GallerySort.newest,
    this.size = SizeRange.any,
  });

  static const defaults = GalleryOptions();

  final GallerySort sort;
  final SizeRange size;

  /// True when results must come from the fully measured library.
  bool get needsSizes => sort.isSizeBased || size.isActive;

  bool get isDefault => this == defaults;

  /// How many settings differ from the defaults (for the badge).
  int get activeCount =>
      (sort != GallerySort.newest ? 1 : 0) + (size.isActive ? 1 : 0);

  GalleryOptions copyWith({GallerySort? sort, SizeRange? size}) =>
      GalleryOptions(sort: sort ?? this.sort, size: size ?? this.size);

  @override
  bool operator ==(Object other) =>
      other is GalleryOptions && other.sort == sort && other.size == size;

  @override
  int get hashCode => Object.hash(sort, size);
}

/// Keeps items whose measured size is inside [range]. Items without a
/// known size are excluded, since we can't honestly say they match.
List<MediaItem> filterBySize(
  List<MediaItem> items,
  SizeRange range,
  int? Function(MediaItem item) sizeOf,
) {
  if (!range.isActive) return items;
  final matching = <MediaItem>[];
  for (final item in items) {
    final bytes = sizeOf(item);
    if (bytes != null && range.contains(bytes)) matching.add(item);
  }
  return matching;
}

/// Sorts by date or size. For size sorts, items with an unknown size go
/// last; ties keep newest first.
List<MediaItem> sortMedia(
  Iterable<MediaItem> items,
  GallerySort sort,
  int? Function(MediaItem item) sizeOf,
) {
  final byDate = sortNewestFirst(items);
  switch (sort) {
    case GallerySort.newest:
      return byDate;
    case GallerySort.oldest:
      final dated = byDate.where((m) => m.createdAt != null).toList().reversed;
      return [...dated, ...byDate.where((m) => m.createdAt == null)];
    case GallerySort.largest:
    case GallerySort.smallest:
      final known = byDate.where((m) => sizeOf(m) != null).toList();
      known.sort((a, b) {
        final diff = sizeOf(a)!.compareTo(sizeOf(b)!);
        return sort == GallerySort.largest ? -diff : diff;
      });
      return [...known, ...byDate.where((m) => sizeOf(m) == null)];
  }
}

/// Size sections used when sorting by size, e.g. "10 MB – 100 MB".
const sizeBucketBounds = [
  1000 * 1000 * 1000,
  100 * 1000 * 1000,
  10 * 1000 * 1000,
  1000 * 1000,
];

String sizeBucketLabel(int? bytes) {
  if (bytes == null) return 'Size unknown';
  if (bytes >= sizeBucketBounds[0]) return 'Over 1 GB';
  if (bytes >= sizeBucketBounds[1]) return '100 MB – 1 GB';
  if (bytes >= sizeBucketBounds[2]) return '10 MB – 100 MB';
  if (bytes >= sizeBucketBounds[3]) return '1 MB – 10 MB';
  return 'Under 1 MB';
}

/// Groups size-sorted items into consecutive size sections.
List<MediaDayGroup> groupBySize(
  List<MediaItem> items,
  int? Function(MediaItem item) sizeOf,
) {
  final groups = <MediaDayGroup>[];
  for (final item in items) {
    final label = sizeBucketLabel(sizeOf(item));
    if (groups.isEmpty || groups.last.label != label) {
      groups.add(MediaDayGroup(label: label, items: []));
    }
    groups.last.items.add(item);
  }
  return groups;
}
