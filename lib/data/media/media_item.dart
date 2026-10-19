/// One photo or video, from either the device library or the demo catalogue.
///
/// This is a plain Dart class with no device-specific types, so widgets and
/// tests can use it without knowing where the media came from.
library;

enum MediaKind { photo, video }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.width = 0,
    this.height = 0,
    this.duration,
    this.title,
    this.mimeType,
    this.isDeviceFavorite = false,
    this.assetPath,
    this.tags = const [],
  });

  /// Stable identifier. On iOS this is the PhotoKit local identifier, on
  /// Android the MediaStore id, and for demo media the bundled file name.
  final String id;

  final MediaKind kind;

  /// When the photo or video was taken. Null when the platform doesn't know.
  final DateTime? createdAt;

  /// Pixel size (already corrected for rotation). 0 when unknown.
  final int width;
  final int height;

  /// Video length, when known.
  final Duration? duration;

  /// File name or description, when available.
  final String? title;

  /// e.g. "image/jpeg". Often only known after a details request on iOS.
  final String? mimeType;

  /// Favorited in the system Photos / Gallery app. This is separate from
  /// Pictora's own favorites, which the app manages itself.
  final bool isDeviceFavorite;

  /// Only set for bundled demo media (an asset path inside the app).
  final String? assetPath;

  /// Search keywords (demo media only for now).
  final List<String> tags;

  bool get isVideo => kind == MediaKind.video;
  bool get isDemo => assetPath != null;

  /// Width / height, falling back to square when the size is unknown.
  double get aspectRatio => width > 0 && height > 0 ? width / height : 1.0;

  /// A short human description for screen readers.
  String get accessibilityLabel {
    final kindLabel = isVideo ? 'Video' : 'Photo';
    return title == null ? kindLabel : '$kindLabel: $title';
  }

  @override
  bool operator ==(Object other) => other is MediaItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
