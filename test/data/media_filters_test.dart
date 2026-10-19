import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/media/media_filters.dart';
import 'package:pictoria/data/media/media_item.dart';

MediaItem item(
  String id, {
  DateTime? at,
  MediaKind kind = MediaKind.photo,
  String? title,
  List<String> tags = const [],
}) => MediaItem(id: id, kind: kind, createdAt: at, title: title, tags: tags);

void main() {
  final today = DateTime(2026, 10, 17, 9); // a Saturday

  group('sortNewestFirst', () {
    test('orders by date descending and puts undated items last', () {
      final sorted = sortNewestFirst([
        item('old', at: DateTime(2024, 1, 1)),
        item('undated'),
        item('new', at: DateTime(2026, 10, 17)),
        item('mid', at: DateTime(2025, 6, 1)),
      ]);
      expect(sorted.map((m) => m.id), ['new', 'mid', 'old', 'undated']);
    });
  });

  group('mergeById', () {
    test('appends a page and skips duplicates', () {
      final merged = mergeById([item('a'), item('b')], [item('b'), item('c')]);
      expect(merged.map((m) => m.id), ['a', 'b', 'c']);
    });
  });

  group('filterMedia', () {
    final media = [
      item('p1', at: today, title: 'Beach day', tags: ['sea']),
      item('v1', at: today, kind: MediaKind.video),
      item('p2', at: DateTime(2025, 3, 2)),
    ];

    test('All returns everything', () {
      expect(filterMedia(media, filter: GalleryFilter.all, now: today), media);
    });

    test('Photos and Videos split by kind', () {
      expect(
        filterMedia(
          media,
          filter: GalleryFilter.photos,
          now: today,
        ).map((m) => m.id),
        ['p1', 'p2'],
      );
      expect(
        filterMedia(
          media,
          filter: GalleryFilter.videos,
          now: today,
        ).map((m) => m.id),
        ['v1'],
      );
    });

    test('Favorites uses the app-managed id set', () {
      final result = filterMedia(
        media,
        filter: GalleryFilter.favorites,
        favorites: {'p2'},
        now: today,
      );
      expect(result.map((m) => m.id), ['p2']);
    });

    test('search matches title, tags, kind and date words', () {
      List<String> search(String q) => filterMedia(
        media,
        filter: GalleryFilter.all,
        query: q,
        now: today,
      ).map((m) => m.id).toList();

      expect(search('beach'), ['p1']);
      expect(search('SEA'), ['p1']);
      expect(search('video'), ['v1']);
      expect(search('today'), ['p1', 'v1']);
      expect(search('march'), ['p2']);
      expect(search('2025'), ['p2']);
      expect(search('   '), ['p1', 'v1', 'p2']);
      expect(search('nothing-like-this'), isEmpty);
    });
  });

  group('groupByDay', () {
    test('groups consecutive items by calendar day with friendly labels', () {
      final groups = groupByDay([
        item('a', at: DateTime(2026, 10, 17, 20)),
        item('b', at: DateTime(2026, 10, 17, 1)),
        item('c', at: DateTime(2026, 10, 16, 12)),
        item('d', at: DateTime(2026, 10, 1)),
        item('e'),
      ], now: today);

      expect(groups.map((g) => g.label), [
        'Today',
        'Yesterday',
        '1 October',
        'Undated',
      ]);
      expect(groups.first.items.map((m) => m.id), ['a', 'b']);
    });
  });

  group('dayLabel', () {
    test('uses Today, Yesterday, weekday, date, and year for old dates', () {
      expect(dayLabel(DateTime(2026, 10, 17, 23), today), 'Today');
      expect(dayLabel(DateTime(2026, 10, 16), today), 'Yesterday');
      expect(dayLabel(DateTime(2026, 10, 14), today), 'Wednesday');
      expect(dayLabel(DateTime(2026, 10, 6), today), '6 October');
      expect(dayLabel(DateTime(2024, 12, 25), today), '25 December 2024');
    });
  });

  group('formatting', () {
    test('formatDuration', () {
      expect(formatDuration(const Duration(seconds: 24)), '0:24');
      expect(formatDuration(const Duration(minutes: 3, seconds: 5)), '3:05');
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('formatFileSize', () {
      // Decimal units, matching iOS and Android Settings.
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(2048), '2.0 KB');
      expect(formatFileSize(5 * 1000 * 1000), '5.0 MB');
      expect(formatFileSize(150 * 1000 * 1000), '150 MB');
      expect(formatFileSize(128 * 1000 * 1000 * 1000), '128 GB');
    });
  });

  test('MediaItem aspect ratio falls back to square when size is unknown', () {
    expect(item('x').aspectRatio, 1.0);
    expect(
      const MediaItem(
        id: 'y',
        kind: MediaKind.photo,
        createdAt: null,
        width: 300,
        height: 200,
      ).aspectRatio,
      1.5,
    );
  });

  group('sorting and size filters', () {
    final a = item('a', at: DateTime(2026, 10, 3)); // 5 MB
    final b = item('b', at: DateTime(2026, 10, 2)); // 50 MB
    final c = item('c', at: DateTime(2026, 10, 1)); // size unknown
    final d = item('d'); // undated, 500 KB
    final sizes = {'a': 5000000, 'b': 50000000, 'd': 500000};
    int? sizeOf(MediaItem m) => sizes[m.id];
    List<String> ids(List<MediaItem> items) => items.map((m) => m.id).toList();

    test('newest and oldest keep undated items last', () {
      expect(ids(sortMedia([d, c, a, b], GallerySort.newest, sizeOf)), [
        'a',
        'b',
        'c',
        'd',
      ]);
      expect(ids(sortMedia([d, c, a, b], GallerySort.oldest, sizeOf)), [
        'c',
        'b',
        'a',
        'd',
      ]);
    });

    test('largest and smallest put unknown sizes last', () {
      expect(ids(sortMedia([a, b, c, d], GallerySort.largest, sizeOf)), [
        'b',
        'a',
        'd',
        'c',
      ]);
      expect(ids(sortMedia([a, b, c, d], GallerySort.smallest, sizeOf)), [
        'd',
        'a',
        'b',
        'c',
      ]);
    });

    test('size ranges are inclusive and skip unknown sizes', () {
      const range = SizeRange(minBytes: 5000000, maxBytes: 50000000);
      expect(ids(filterBySize([a, b, c, d], range, sizeOf)), ['a', 'b']);
      expect(ids(filterBySize([a, b, c, d], SizeRange.any, sizeOf)), [
        'a',
        'b',
        'c',
        'd',
      ], reason: 'no range means no filtering');
    });

    test('range labels read naturally', () {
      expect(SizeRange.any.label, 'Any size');
      expect(const SizeRange(minBytes: 10000000).label, 'Over 10 MB');
      expect(const SizeRange(maxBytes: 1000000).label, 'Under 1.0 MB');
      expect(
        const SizeRange(minBytes: 1000000, maxBytes: 10000000).label,
        '1.0 MB – 10 MB',
      );
    });

    test('size sorts are grouped into size sections', () {
      final sorted = sortMedia([a, b, c, d], GallerySort.largest, sizeOf);
      final groups = groupBySize(sorted, sizeOf);
      expect(groups.map((g) => g.label), [
        '10 MB – 100 MB',
        '1 MB – 10 MB',
        'Under 1 MB',
        'Size unknown',
      ]);
    });

    test('options know when sizes are needed and what is active', () {
      expect(GalleryOptions.defaults.needsSizes, isFalse);
      expect(GalleryOptions.defaults.activeCount, 0);
      const oldest = GalleryOptions(sort: GallerySort.oldest);
      expect(oldest.needsSizes, isFalse, reason: 'the platform sorts dates');
      expect(oldest.activeCount, 1);
      const sized = GalleryOptions(
        sort: GallerySort.largest,
        size: SizeRange(minBytes: 1000000),
      );
      expect(sized.needsSizes, isTrue);
      expect(sized.activeCount, 2);
    });
  });
}
