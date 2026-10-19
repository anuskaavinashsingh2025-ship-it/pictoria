import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pictoria/data/media/device_media_repository.dart';
import 'package:pictoria/data/media/media_access.dart';
import 'package:pictoria/data/media/media_item.dart';
import 'package:pictoria/data/media/media_repository.dart';

// AssetType indexes in photo_manager: other=0, image=1, video=2, audio=3.
const _image = 1;
const _video = 2;
const _audio = 3;

void main() {
  group('mediaItemFromAsset', () {
    test('maps a photo with id, date, size, title and favorite flag', () {
      final item = mediaItemFromAsset(
        AssetEntity(
          id: 'ABC-123/L0/001',
          typeInt: _image,
          width: 4032,
          height: 3024,
          createDateSecond: 1760000000,
          title: 'IMG_0001.HEIC',
          mimeType: 'image/heic',
          isFavorite: true,
        ),
      )!;

      expect(item.id, 'ABC-123/L0/001');
      expect(item.kind, MediaKind.photo);
      expect(
        item.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1760000000 * 1000),
      );
      expect(item.width, 4032);
      expect(item.height, 3024);
      expect(item.title, 'IMG_0001.HEIC');
      expect(item.mimeType, 'image/heic');
      expect(item.isDeviceFavorite, isTrue);
      expect(item.duration, isNull);
      expect(item.isDemo, isFalse);
    });

    test('maps a video with its duration', () {
      final item = mediaItemFromAsset(
        AssetEntity(
          id: 'v',
          typeInt: _video,
          width: 1920,
          height: 1080,
          duration: 42,
          createDateSecond: 1,
        ),
      )!;
      expect(item.kind, MediaKind.video);
      expect(item.duration, const Duration(seconds: 42));
    });

    test('swaps width and height for rotated media', () {
      final item = mediaItemFromAsset(
        AssetEntity(
          id: 'r',
          typeInt: _image,
          width: 4000,
          height: 3000,
          orientation: 90,
        ),
      )!;
      expect(item.width, 3000);
      expect(item.height, 4000);
    });

    test('falls back to modified date, then to no date', () {
      final modifiedOnly = mediaItemFromAsset(
        AssetEntity(
          id: 'm',
          typeInt: _image,
          width: 1,
          height: 1,
          modifiedDateSecond: 1700000000,
        ),
      )!;
      expect(
        modifiedOnly.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );

      final undated = mediaItemFromAsset(
        AssetEntity(id: 'u', typeInt: _image, width: 0, height: 0),
      )!;
      expect(undated.createdAt, isNull);
      expect(undated.aspectRatio, 1.0);
    });

    test('treats an empty title as missing', () {
      final item = mediaItemFromAsset(
        AssetEntity(id: 't', typeInt: _image, width: 1, height: 1, title: ''),
      )!;
      expect(item.title, isNull);
    });

    test('skips audio and unknown asset types', () {
      expect(
        mediaItemFromAsset(
          AssetEntity(id: 'a', typeInt: _audio, width: 0, height: 0),
        ),
        isNull,
      );
      expect(
        mediaItemFromAsset(
          AssetEntity(id: 'o', typeInt: 0, width: 0, height: 0),
        ),
        isNull,
      );
    });
  });

  group('mapPermissionState', () {
    MediaAccess map(
      PermissionState state, {
      TargetPlatform platform = TargetPlatform.android,
      int denied = 0,
    }) => mapPermissionState(state, platform: platform, deniedRequests: denied);

    test('maps the simple states directly', () {
      expect(map(PermissionState.notDetermined), MediaAccess.notDetermined);
      expect(map(PermissionState.authorized), MediaAccess.granted);
      expect(map(PermissionState.limited), MediaAccess.limited);
      expect(map(PermissionState.restricted), MediaAccess.restricted);
    });

    test('iOS denial is always permanent (no second prompt)', () {
      expect(
        map(PermissionState.denied, platform: TargetPlatform.iOS),
        MediaAccess.permanentlyDenied,
      );
    });

    test('Android: denied before any request means "not asked yet"', () {
      // Android reports "denied" for a permission that was never requested.
      expect(map(PermissionState.denied, denied: 0), MediaAccess.notDetermined);
    });

    test('Android denial becomes permanent after repeated denials', () {
      expect(map(PermissionState.denied, denied: 1), MediaAccess.denied);
      expect(
        map(PermissionState.denied, denied: 2),
        MediaAccess.permanentlyDenied,
      );
    });
  });

  test('requestTypeFor maps gallery filters to plugin request types', () {
    expect(requestTypeFor(MediaTypeFilter.all), RequestType.common);
    expect(requestTypeFor(MediaTypeFilter.photos), RequestType.image);
    expect(requestTypeFor(MediaTypeFilter.videos), RequestType.video);
  });

  test('MediaAccess helpers', () {
    expect(MediaAccess.granted.canReadMedia, isTrue);
    expect(MediaAccess.limited.canReadMedia, isTrue);
    expect(MediaAccess.denied.canReadMedia, isFalse);
    expect(MediaAccess.notDetermined.canRequest, isTrue);
    expect(MediaAccess.permanentlyDenied.canRequest, isFalse);
    expect(MediaAccess.permanentlyDenied.shouldOfferSettings, isTrue);
  });

  group('classifyDeletion', () {
    DeletionResult classify({
      Set<String> requested = const {'a', 'b', 'c'},
      Set<String> missing = const {},
      Set<String> returned = const {},
      Object? error,
    }) => classifyDeletion(
      mode: DeletionMode.recentlyDeleted,
      requestedIds: requested,
      missingIds: missing,
      returnedIds: returned,
      error: error,
    );

    test('everything confirmed is a success', () {
      final r = classify(returned: {'a', 'b', 'c'});
      expect(r.status, DeletionStatus.success);
      expect(r.deletedIds, {'a', 'b', 'c'});
      expect(r.failedIds, isEmpty);
    });

    test('some confirmed is partial; the rest stay queued', () {
      final r = classify(returned: {'a'});
      expect(r.status, DeletionStatus.partial);
      expect(r.deletedIds, {'a'});
      expect(r.failedIds, {'b', 'c'});
    });

    test('an empty reply without an error means the user cancelled', () {
      final r = classify();
      expect(r.status, DeletionStatus.cancelled);
      expect(r.resolvedIds, isEmpty);
    });

    test('an error with nothing removed is a failure', () {
      final r = classify(error: Exception('boom'));
      expect(r.status, DeletionStatus.failed);
      expect(r.failedIds, {'a', 'b', 'c'});
    });

    test('already-missing items are reported apart from deleted ones', () {
      // iOS replies with every requested id on success, even missing ones.
      final r = classify(missing: {'c'}, returned: {'a', 'b', 'c'});
      expect(r.status, DeletionStatus.success);
      expect(r.deletedIds, {'a', 'b'});
      expect(r.missingIds, {'c'});
      expect(r.resolvedIds, {'a', 'b', 'c'});
    });

    test('ids the platform invents are ignored', () {
      final r = classify(returned: {'a', 'b', 'c', 'zzz'});
      expect(r.deletedIds, {'a', 'b', 'c'});
    });
  });
}
