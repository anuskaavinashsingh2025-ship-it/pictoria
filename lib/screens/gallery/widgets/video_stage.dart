import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../data/media/media_filters.dart';
import '../../../data/media/media_item.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';

/// Builds a player for a local video file. Tests pass a fake one, so they
/// never need real playback.
typedef VideoControllerFactory = VideoPlayerController Function(File file);

/// Plays one video in the full-screen viewer.
///
/// The player is created when this widget appears and disposed when it goes
/// away. Nothing plays until the user presses Play, and playback pauses when
/// the app goes to the background.
///
/// [poster] (the thumbnail) is shown while the video loads, and stays
/// underneath it so the Hero animation back to the grid still has a picture.
class VideoStage extends StatefulWidget {
  const VideoStage({
    super.key,
    required this.item,
    required this.poster,
    required this.loadFile,
    this.createController = VideoPlayerController.file,
  });

  final MediaItem item;
  final Widget poster;
  final Future<File?> Function() loadFile;
  final VideoControllerFactory createController;

  @override
  State<VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<VideoStage> with WidgetsBindingObserver {
  VideoPlayerController? _player;

  /// True when there is no file to play or the player couldn't open it.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  Future<void> _open() async {
    final file = await widget.loadFile();
    if (!mounted) return;
    if (file == null) {
      setState(() => _failed = true);
      return;
    }
    // Assigned before awaiting, so dispose() cleans it up if the viewer
    // closes while the video is still loading.
    final player = widget.createController(file)..addListener(_onPlayerChanged);
    _player = player;
    try {
      await player.initialize();
    } catch (error) {
      debugPrint('Video failed for ${widget.item.id}: $error');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _player?.value.isPlaying == true) {
      _player!.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player
      ?..removeListener(_onPlayerChanged)
      ..dispose();
    super.dispose();
  }

  void _togglePlay() {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    player.value.isPlaying ? player.pause() : player.play();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final failed = _failed || (player?.value.hasError ?? false);
    final ready = !failed && player != null && player.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Hidden (not removed) once the video shows, so the Hero keeps it.
        Opacity(opacity: ready ? 0 : 1, child: widget.poster),
        if (failed)
          _VideoMessage(
            message: widget.item.isDemo
                ? 'Demo videos are still photos, so there is nothing to play.'
                : "This video can't be played right now.",
          )
        else if (!ready)
          Center(
            child: Semantics(
              label: 'Loading video',
              child: const CircularProgressIndicator(color: AppColors.lavender),
            ),
          )
        else
          Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: player.value.aspectRatio,
                    child: VideoPlayer(player),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.md,
                  AppSpacing.screen,
                  0,
                ),
                child: _Controls(player: player, onToggle: _togglePlay),
              ),
            ],
          ),
      ],
    );
  }
}

/// Play/pause button, scrubbable progress bar and elapsed time.
class _Controls extends StatelessWidget {
  const _Controls({required this.player, required this.onToggle});

  final VideoPlayerController player;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final value = player.value;
    final label = value.isPlaying ? 'Pause video' : 'Play video';
    final icon = value.isPlaying
        ? Icons.pause_rounded
        : value.isCompleted
        ? Icons.replay_rounded
        : Icons.play_arrow_rounded;

    return Row(
      children: [
        Semantics(
          button: true,
          label: label,
          onTap: onToggle,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: AppShadows.glow,
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: VideoProgressIndicator(
              player,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              colors: VideoProgressColors(
                playedColor: AppColors.primary,
                bufferedColor: AppColors.lavender.withValues(alpha: 0.5),
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          '${formatDuration(value.position)} / '
          '${formatDuration(value.duration)}',
          style: AppText.caption.copyWith(color: AppColors.lavender),
        ),
      ],
    );
  }
}

class _VideoMessage extends StatelessWidget {
  const _VideoMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.screen),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: AppColors.lavender,
              size: 36,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
