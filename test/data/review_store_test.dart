import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/media/media_item.dart';
import 'package:pictoria/data/review/review_record.dart';
import 'package:pictoria/data/review/review_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final video = MediaItem(
    id: 'ABC/L0/001',
    kind: MediaKind.video,
    createdAt: DateTime(2026, 10, 1, 9, 30),
    width: 1920,
    height: 1080,
    duration: const Duration(seconds: 42),
    title: 'IMG_1.MOV',
    mimeType: 'video/quicktime',
  );

  ReviewSnapshot sample() => ReviewSnapshot(
    records: {
      video.id: ReviewRecord(
        item: video,
        decision: ReviewDecision.delete,
        decidedAt: DateTime(2026, 10, 2),
        fileSizeBytes: 12345,
      ),
    },
    pendingDeletionIds: {'ABC/L0/001'},
  );

  test('a snapshot survives an encode/decode round trip', () {
    final decoded = SharedPreferencesReviewStore.decodeSnapshot(
      SharedPreferencesReviewStore.encodeSnapshot(sample()),
    );
    final record = decoded.records[video.id]!;

    expect(record.decision, ReviewDecision.delete);
    expect(record.fileSizeBytes, 12345);
    expect(record.item.kind, MediaKind.video);
    expect(record.item.createdAt, DateTime(2026, 10, 1, 9, 30));
    expect(record.item.duration, const Duration(seconds: 42));
    expect(record.item.title, 'IMG_1.MOV');
    expect(record.item.mimeType, 'video/quicktime');
    expect(record.item.width, 1920);
    expect(decoded.pendingDeletionIds, {'ABC/L0/001'});
  });

  test('stores ids and metadata only, never image data', () {
    final json = SharedPreferencesReviewStore.encodeSnapshot(sample());
    expect(json.length, lessThan(500));
    expect(json, isNot(contains('bytes')));
  });

  test('persists through SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesReviewStore().save(sample());

    // A fresh store instance (like after an app restart) reads it back.
    final loaded = await SharedPreferencesReviewStore().load();
    expect(loaded.records.keys, [video.id]);
  });

  test('corrupt or unknown data loads as empty instead of crashing', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesReviewStore.storageKey: '{not json',
    });
    expect((await SharedPreferencesReviewStore().load()).records, isEmpty);

    expect(
      SharedPreferencesReviewStore.decodeSnapshot('{"version": 99}').records,
      isEmpty,
    );
  });

  test('skips malformed records but keeps the good ones', () {
    final decoded = SharedPreferencesReviewStore.decodeSnapshot(
      '{"version":1,"records":['
      '{"decision":"delete","item":{"id":"ok","kind":"photo"}},'
      '{"decision":"explode","item":{"id":"bad","kind":"photo"}},'
      '{"decision":"keep","item":{"kind":"photo"}}'
      ']}',
    );
    expect(decoded.records.keys, ['ok']);
  });
}
