import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// An [ImageProvider] that decodes thumbnail bytes from a [MediaRepository].
///
/// Because it is a real ImageProvider, Flutter's built-in [ImageCache] keeps
/// recently shown thumbnails in memory: scrolling back up or returning from
/// the viewer reuses them instead of asking the platform again.
///
/// Two providers are "the same image" when [cacheKey], [width] and [height]
/// match; the [loader] callback is not part of that comparison.
@immutable
class MediaThumbnailProvider extends ImageProvider<MediaThumbnailProvider> {
  const MediaThumbnailProvider({
    required this.cacheKey,
    required this.width,
    required this.height,
    required this.loader,
  });

  /// Unique per media item (and per library source).
  final String cacheKey;

  /// Requested size in physical pixels.
  final int width;
  final int height;

  /// Fetches the encoded bytes, or returns null if unavailable.
  final Future<Uint8List?> Function() loader;

  @override
  Future<MediaThumbnailProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<MediaThumbnailProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    MediaThumbnailProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadCodec(decode),
      scale: 1.0,
      debugLabel: cacheKey,
    );
  }

  Future<ui.Codec> _loadCodec(ImageDecoderCallback decode) async {
    final bytes = await loader();
    if (bytes == null || bytes.isEmpty) {
      // Reported to the Image widget's errorBuilder, which shows a placeholder.
      throw StateError('Thumbnail unavailable for $cacheKey');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is MediaThumbnailProvider &&
      other.cacheKey == cacheKey &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(cacheKey, width, height);

  @override
  String toString() => 'MediaThumbnailProvider($cacheKey, ${width}x$height)';
}
