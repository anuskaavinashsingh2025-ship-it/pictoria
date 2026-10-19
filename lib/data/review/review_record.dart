import '../media/media_item.dart';

/// What the user decided about one photo or video.
enum ReviewDecision { keep, delete }

/// A saved review decision plus just enough metadata to show the item again
/// (thumbnail lookup, date, type, size) without re-scanning the library.
/// Image data is never stored — only the stable media id and small fields.
class ReviewRecord {
  const ReviewRecord({
    required this.item,
    required this.decision,
    required this.decidedAt,
    this.fileSizeBytes,
  });

  final MediaItem item;
  final ReviewDecision decision;
  final DateTime decidedAt;

  /// Remembered once known, so the deletion queue can show sizes instantly.
  final int? fileSizeBytes;

  String get id => item.id;

  ReviewRecord copyWith({int? fileSizeBytes}) => ReviewRecord(
    item: item,
    decision: decision,
    decidedAt: decidedAt,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
  );

  Map<String, Object?> toJson() => {
    'decision': decision.name,
    'decidedAt': decidedAt.toIso8601String(),
    if (fileSizeBytes != null) 'size': fileSizeBytes,
    'item': mediaItemToJson(item),
  };

  /// Returns null for malformed entries, so one bad record can't break the
  /// whole queue.
  static ReviewRecord? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final decision = ReviewDecision.values.asNameMap()[json['decision']];
    final item = mediaItemFromJson(json['item']);
    if (decision == null || item == null) return null;
    return ReviewRecord(
      item: item,
      decision: decision,
      decidedAt:
          DateTime.tryParse(json['decidedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      fileSizeBytes: json['size'] as int?,
    );
  }
}

/// Everything the review feature persists between app launches.
class ReviewSnapshot {
  const ReviewSnapshot({
    this.records = const {},
    this.pendingDeletionIds = const {},
  });

  /// Decisions by media id.
  final Map<String, ReviewRecord> records;

  /// Ids handed to the system for deletion whose outcome we never recorded
  /// (e.g. the app was closed mid-request). Checked on the next visit.
  final Set<String> pendingDeletionIds;

  static const empty = ReviewSnapshot();
}

/// Minimal JSON form of a [MediaItem]. Demo items keep their asset path so
/// they can still be drawn after a restart.
Map<String, Object?> mediaItemToJson(MediaItem item) => {
  'id': item.id,
  'kind': item.kind.name,
  if (item.createdAt != null) 'createdAt': item.createdAt!.toIso8601String(),
  if (item.width > 0) 'w': item.width,
  if (item.height > 0) 'h': item.height,
  if (item.duration != null) 'durationMs': item.duration!.inMilliseconds,
  if (item.title != null) 'title': item.title,
  if (item.mimeType != null) 'mime': item.mimeType,
  if (item.assetPath != null) 'asset': item.assetPath,
};

MediaItem? mediaItemFromJson(Object? json) {
  if (json is! Map) return null;
  final id = json['id'];
  final kind = MediaKind.values.asNameMap()[json['kind']];
  if (id is! String || id.isEmpty || kind == null) return null;
  final durationMs = json['durationMs'] as int?;
  return MediaItem(
    id: id,
    kind: kind,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    width: json['w'] as int? ?? 0,
    height: json['h'] as int? ?? 0,
    duration: durationMs == null ? null : Duration(milliseconds: durationMs),
    title: json['title'] as String?,
    mimeType: json['mime'] as String?,
    assetPath: json['asset'] as String?,
  );
}
