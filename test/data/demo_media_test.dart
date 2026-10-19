import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/demo_media.dart';
import 'package:pictoria/data/media/demo_media_repository.dart';
import 'package:pictoria/data/media/media_item.dart';
import 'package:pictoria/data/media/media_repository.dart';

void main() {
  final now = DateTime(2026, 10, 19);
  final videos = demoPhotos.where((photo) => photo.kind == MediaKind.video);
  final repository = DemoMediaRepository();

  test('every demo video has a bundled clip', () {
    expect(videos, isNotEmpty);
    for (final photo in videos) {
      expect(
        File(photo.videoAssetPath!).existsSync(),
        isTrue,
        reason: photo.id,
      );
      expect(photo.toMediaItem(now).mimeType, 'video/mp4');
    }
  });

  test('demo videos play their clip; photos have nothing to play', () async {
    final video = videos.first.toMediaItem(now);
    final source = await repository.loadVideo(video);
    expect(
      (source! as AssetVideoSource).assetPath,
      videos.first.videoAssetPath,
    );

    final photo = demoPhotos
        .firstWhere((photo) => photo.kind == MediaKind.photo)
        .toMediaItem(now);
    expect(photo.mimeType, 'image/jpeg');
    expect(await repository.loadVideo(photo), isNull);
  });
}
