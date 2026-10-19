import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pictoria/data/demo_media.dart';
import 'package:pictoria/data/media/media_item.dart';
import 'package:pictoria/data/media/media_repository.dart';
import 'package:pictoria/screens/gallery/media_viewer_screen.dart';
import 'package:pictoria/state/gallery_controller.dart';
import 'package:video_player/video_player.dart';

import 'semantics_actions_test.dart' show expectTapAction, semanticsTap;
import 'support/fake_media_repository.dart';

/// A player that never touches the platform: tests decide when it finishes
/// loading, whether it fails, and inspect what the viewer asked it to do.
class FakeVideoPlayerController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  FakeVideoPlayerController({this.initGate, this.initError})
    : super(const VideoPlayerValue(duration: Duration.zero));

  final Completer<void>? initGate;
  final Object? initError;
  bool disposed = false;
  int playCalls = 0;

  @override
  int get playerId => VideoPlayerController.kUninitializedPlayerId;

  @override
  Future<void> initialize() async {
    await initGate?.future;
    if (disposed) return; // like the real player, which stops listening
    if (initError != null) throw initError!;
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(seconds: 15),
      size: const Size(1920, 1080),
    );
  }

  @override
  Future<void> play() async {
    playCalls++;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);

  @override
  Future<void> seekTo(Duration position) async =>
      value = value.copyWith(position: position);

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _video = MediaItem(
  id: 'video-1',
  kind: MediaKind.video,
  createdAt: null,
  width: 1920,
  height: 1080,
  duration: Duration(seconds: 15),
  title: 'Beach.mov',
);

const _photo = MediaItem(
  id: 'photo-1',
  kind: MediaKind.photo,
  createdAt: null,
  width: 4032,
  height: 3024,
  title: 'IMG_1.HEIC',
);

void main() {
  late FakeMediaRepository repository;
  late GalleryController gallery;
  late List<FakeVideoPlayerController> created;
  late List<VideoSource> sources;
  FakeVideoPlayerController Function() makePlayer =
      FakeVideoPlayerController.new;

  setUp(() {
    repository = FakeMediaRepository();
    gallery = GalleryController(deviceRepository: repository);
    created = [];
    sources = [];
    makePlayer = FakeVideoPlayerController.new;
  });

  tearDown(() => gallery.dispose());

  VideoPlayerController factory(VideoSource source) {
    sources.add(source);
    final player = makePlayer();
    created.add(player);
    return player;
  }

  /// Opens the viewer from a home page, so tests can close it again.
  Future<void> openViewer(WidgetTester tester, MediaItem item) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MediaViewerScreen(
                  item: item,
                  controller: gallery,
                  createVideoController: factory,
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    // Not pumpAndSettle: the loading spinner animates forever.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('photos still show the zoomable image, with no player', (
    tester,
  ) async {
    await openViewer(tester, _photo);

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image && widget.semanticLabel == 'Photo: IMG_1.HEIC',
      ),
      findsOneWidget,
    );
    expect(find.text('IMG_1.HEIC'), findsOneWidget);
    expect(find.bySemanticsLabel('Play video'), findsNothing);
    expect(created, isEmpty);
    expect(repository.videoCalls, 0);
  });

  testWidgets('shows a loading state until the video is ready', (tester) async {
    final gate = Completer<void>();
    makePlayer = () => FakeVideoPlayerController(initGate: gate);
    await openViewer(tester, _video);

    expect(find.bySemanticsLabel('Loading video'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Play video'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Loading video'), findsNothing);
    expect(find.bySemanticsLabel('Play video'), findsOneWidget);
    expect(find.text('0:00 / 0:15'), findsOneWidget);
    expect(
      find.textContaining('later milestone'),
      findsNothing,
      reason: 'the old placeholder is gone',
    );
  });

  testWidgets('does not autoplay, and play/pause toggles playback', (
    tester,
  ) async {
    await openViewer(tester, _video);
    final player = created.single;
    expect(player.value.isPlaying, isFalse);
    expect(player.playCalls, 0);

    await tester.tap(find.bySemanticsLabel('Play video'));
    await tester.pump();
    expect(player.value.isPlaying, isTrue);
    expect(find.bySemanticsLabel('Pause video'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Pause video'));
    await tester.pump();
    expect(player.value.isPlaying, isFalse);
    expect(find.bySemanticsLabel('Play video'), findsOneWidget);
  });

  testWidgets('play button works through screen-reader activation', (
    tester,
  ) async {
    await openViewer(tester, _video);
    final button = find.bySemanticsLabel('Play video');
    expectTapAction(tester, button);

    await semanticsTap(tester, button);
    expect(created.single.value.isPlaying, isTrue);
  });

  testWidgets('shows an error when the player cannot open the video', (
    tester,
  ) async {
    makePlayer = () => FakeVideoPlayerController(initError: Exception('codec'));
    await openViewer(tester, _video);

    expect(find.text("This video can't be played right now."), findsOneWidget);
    expect(find.bySemanticsLabel('Play video'), findsNothing);
    expect(find.bySemanticsLabel('Loading video'), findsNothing);
  });

  testWidgets('shows an error when there is no file to play', (tester) async {
    repository.video = null;
    await openViewer(tester, _video);

    expect(find.text("This video can't be played right now."), findsOneWidget);
    expect(created, isEmpty);
  });

  testWidgets('demo videos play their bundled clip', (tester) async {
    final demoVideo = demoPhotos
        .firstWhere((photo) => photo.kind == MediaKind.video)
        .toMediaItem(DateTime.now());
    await openViewer(tester, demoVideo);

    final source = sources.single as AssetVideoSource;
    expect(source.assetPath, 'assets/demo_media/${demoVideo.id}.mp4');
    expect(find.bySemanticsLabel('Play video'), findsOneWidget);
    expect(repository.videoCalls, 0, reason: 'demo items skip the device');
  });

  testWidgets('closing the viewer disposes the player', (tester) async {
    await openViewer(tester, _video);
    final player = created.single;
    await tester.tap(find.bySemanticsLabel('Play video'));
    await tester.pump();

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(player.disposed, isTrue);
  });

  testWidgets('closing while still loading disposes the player', (
    tester,
  ) async {
    final gate = Completer<void>();
    makePlayer = () => FakeVideoPlayerController(initGate: gate);
    await openViewer(tester, _video);

    await tester.tap(find.byType(CloseButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(created.single.disposed, isTrue);

    gate.complete(); // a late "ready" must not touch the closed viewer
    await tester.pumpAndSettle();
  });

  testWidgets('leaving the app pauses playback', (tester) async {
    await openViewer(tester, _video);
    final player = created.single;
    await tester.tap(find.bySemanticsLabel('Play video'));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(player.value.isPlaying, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(player.value.isPlaying, isFalse, reason: 'no surprise resume');
  });
}
