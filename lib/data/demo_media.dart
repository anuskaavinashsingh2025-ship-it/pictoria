/// Bundled demo photos.
///
/// Used by onboarding, and by the Gallery as a fallback when the device
/// library isn't connected (or is empty, e.g. on a fresh simulator).
library;

import 'media/media_item.dart';

/// One bundled sample photo, described relative to "today".
class DemoPhoto {
  const DemoPhoto({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    required this.daysAgo,
    this.kind = MediaKind.photo,
    this.duration,
    this.tags = const [],
    this.initiallyFavorite = false,
  });

  /// Unique id; also the file name (without extension) in assets/demo_media/.
  final String id;

  /// Short human description, used for accessibility labels and search.
  final String title;

  /// Original pixel size. Used to lay out the grid before images load.
  final int width;
  final int height;

  /// How many days ago the item was "captured". Relative, so the demo always
  /// shows a "Today" and "Yesterday" section no matter when it is run.
  final int daysAgo;

  /// Demo videos are short clips made from their photo (see
  /// assets/demo_media/ATTRIBUTION.md); the photo is their thumbnail.
  final MediaKind kind;
  final Duration? duration;

  final List<String> tags;
  final bool initiallyFavorite;

  String get assetPath => 'assets/demo_media/$id.jpg';

  /// The playable clip, for videos only.
  String? get videoAssetPath =>
      kind == MediaKind.video ? 'assets/demo_media/$id.mp4' : null;

  /// Converts to the shared [MediaItem] model, dated relative to [now].
  MediaItem toMediaItem(DateTime now) {
    final midday = DateTime(now.year, now.month, now.day, 12);
    return MediaItem(
      id: id,
      kind: kind,
      createdAt: midday.subtract(Duration(days: daysAgo)),
      width: width,
      height: height,
      duration: duration,
      title: title,
      mimeType: kind == MediaKind.video ? 'video/mp4' : 'image/jpeg',
      assetPath: assetPath,
      tags: tags,
    );
  }
}

/// The bundled demo items, newest first.
const demoPhotos = <DemoPhoto>[
  // Today
  DemoPhoto(
    id: 'sunset_golden_sea',
    title: 'Golden sunset over the sea',
    width: 900,
    height: 600,
    daysAgo: 0,
    tags: ['sunset', 'sea', 'travel', 'sky'],
    initiallyFavorite: true,
  ),
  DemoPhoto(
    id: 'pink_tulips',
    title: 'Pink tulips on a wooden table',
    width: 900,
    height: 600,
    daysAgo: 0,
    tags: ['flowers', 'tulips', 'home'],
  ),
  DemoPhoto(
    id: 'golden_retriever_grass',
    title: 'Golden retriever smiling in the grass',
    width: 900,
    height: 1350,
    daysAgo: 0,
    tags: ['dog', 'pet', 'golden retriever'],
    initiallyFavorite: true,
  ),
  DemoPhoto(
    id: 'ama_dablam_peak',
    title: 'Snowy mountain peak',
    width: 900,
    height: 596,
    daysAgo: 0,
    tags: ['mountain', 'travel', 'nepal', 'snow'],
  ),
  DemoPhoto(
    id: 'dog_beach_run',
    title: 'Dog running on the beach',
    width: 900,
    height: 1348,
    daysAgo: 0,
    kind: MediaKind.video,
    duration: Duration(seconds: 8),
    tags: ['dog', 'pet', 'beach', 'sea'],
  ),
  DemoPhoto(
    id: 'heart_latte',
    title: 'Latte with heart art',
    width: 900,
    height: 1350,
    daysAgo: 0,
    tags: ['coffee', 'cafe', 'latte'],
    initiallyFavorite: true,
  ),
  DemoPhoto(
    id: 'old_town_street',
    title: 'Old town street',
    width: 900,
    height: 583,
    daysAgo: 0,
    tags: ['street', 'travel', 'city'],
  ),

  // Yesterday
  DemoPhoto(
    id: 'friends_picnic',
    title: 'Friends laughing at a picnic',
    width: 900,
    height: 1357,
    daysAgo: 1,
    kind: MediaKind.video,
    duration: Duration(seconds: 6),
    tags: ['friends', 'picnic', 'people'],
  ),
  DemoPhoto(
    id: 'cafe_drinks',
    title: 'Iced drinks at a café',
    width: 900,
    height: 1203,
    daysAgo: 1,
    tags: ['cafe', 'coffee', 'drinks'],
  ),
  DemoPhoto(
    id: 'santorini_sunset',
    title: 'Santorini at dusk',
    width: 900,
    height: 624,
    daysAgo: 1,
    tags: ['santorini', 'greece', 'travel', 'sunset'],
    initiallyFavorite: true,
  ),
  DemoPhoto(
    id: 'tabby_cat_window',
    title: 'Tabby cat by the window',
    width: 900,
    height: 599,
    daysAgo: 1,
    tags: ['cat', 'pet', 'home'],
  ),

  // Earlier this week
  DemoPhoto(
    id: 'manarola_italy',
    title: 'Manarola, Italy',
    width: 900,
    height: 1355,
    daysAgo: 3,
    tags: ['italy', 'travel', 'city', 'sea'],
  ),
  DemoPhoto(
    id: 'pink_blossoms_sky',
    title: 'Pink blossoms against the sky',
    width: 900,
    height: 600,
    daysAgo: 3,
    tags: ['flowers', 'spring', 'sky'],
  ),
  DemoPhoto(
    id: 'birds_sunset',
    title: 'Birds over the sea at sunset',
    width: 900,
    height: 1350,
    daysAgo: 3,
    kind: MediaKind.video,
    duration: Duration(seconds: 10),
    tags: ['sunset', 'birds', 'sea', 'sky'],
  ),
  DemoPhoto(
    id: 'lab_with_tulip',
    title: 'Labrador holding a yellow tulip',
    width: 900,
    height: 1443,
    daysAgo: 3,
    tags: ['dog', 'pet', 'flowers', 'tulips'],
    initiallyFavorite: true,
  ),

  // Older
  DemoPhoto(
    id: 'turquoise_lake',
    title: 'Turquoise mountain lake',
    width: 900,
    height: 600,
    daysAgo: 11,
    tags: ['lake', 'mountain', 'travel'],
  ),
  DemoPhoto(
    id: 'maldives_aerial',
    title: 'Aerial view of a tropical shore',
    width: 900,
    height: 1602,
    daysAgo: 11,
    tags: ['beach', 'sea', 'travel', 'maldives'],
  ),
  DemoPhoto(
    id: 'dandelion_golden_hour',
    title: 'Dandelion at golden hour',
    width: 900,
    height: 1354,
    daysAgo: 11,
    tags: ['flowers', 'dandelion', 'sunset'],
  ),
];

/// Looks up a demo photo by id (used by onboarding to pick collage photos).
DemoPhoto demoById(String id) =>
    demoPhotos.firstWhere((photo) => photo.id == id);
