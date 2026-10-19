import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../state/review_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/doodles.dart';
import '../deletion/deletion_queue_screen.dart';
import '../gallery/widgets/gallery_states.dart';
import 'widgets/review_buttons.dart';
import 'widgets/swipe_card_stack.dart';

/// Swipe Review: decide, one card at a time, what to keep.
///
/// Swiping left only MARKS an item for deletion. Nothing is deleted here.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.controller,
    required this.onClose,
  });

  final ReviewController controller;

  /// Leaves the review (back to the Gallery tab).
  final VoidCallback onClose;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _stackKey = GlobalKey<SwipeCardStackState>();
  UndoEntry? _undoEntry;
  int _undoTick = 0;

  ReviewController get _review => widget.controller;

  @override
  void initState() {
    super.initState();
    // After the first frame: loading notifies listeners, which isn't allowed
    // while widgets are still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _review.ensureLoaded();
    });
  }

  /// Buttons animate the card exactly like a swipe would.
  void _decide(ReviewDecision decision) {
    final stack = _stackKey.currentState;
    if (stack != null) {
      stack.flyOut(decision);
    } else {
      _apply(decision);
    }
  }

  void _apply(ReviewDecision decision) {
    if (decision == ReviewDecision.keep) {
      _review.keep();
    } else {
      _review.markForDeletion();
    }
  }

  void _undo() {
    if (_stackKey.currentState?.isAnimating ?? false) return;
    final action = _review.undo();
    if (action == null) return;
    setState(() => _undoEntry = (tick: ++_undoTick, from: action.decision));
    final verb = action.decision == ReviewDecision.keep
        ? 'Keep'
        : 'Mark for deletion';
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Undid $verb',
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cream,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: _review,
          builder: (context, _) => Column(
            children: [
              _TopBar(
                review: _review,
                onClose: widget.onClose,
                onShowMarked: () => DeletionQueueScreen.open(context, _review),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl + AppSpacing.lg,
                ),
                child: _ProgressBar(value: _review.progress),
              ),
              Expanded(child: _buildCardArea()),
              _ActionRow(
                canDecide: _review.current != null,
                canUndo: _review.canUndo,
                onDelete: () => _decide(ReviewDecision.delete),
                onUndo: _undo,
                onKeep: () => _decide(ReviewDecision.keep),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Swipe left to mark for deletion\nSwipe right to keep',
                textAlign: TextAlign.center,
                style: AppText.caption,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardArea() {
    final current = _review.current;
    Widget content;

    if (current != null) {
      content = SwipeCardStack(
        key: _stackKey,
        current: current,
        next: _review.next,
        imageFor: (item, pixelWidth) =>
            _review.gallery.thumbnailFor(item, pixelWidth: pixelWidth),
        onDecision: _apply,
        undoEntry: _undoEntry,
      );
    } else if (_review.loadError != null) {
      content = GalleryMessage(
        title: 'Something went wrong',
        message: "We couldn't load your photos for review.",
        doodle: DoodleKind.squiggle,
        actionLabel: 'Try again',
        onAction: _review.retry,
      );
    } else if (_review.isLoading || _review.hasMoreToLoad) {
      content = const _LoadingCard();
    } else if (_review.totalCount == 0) {
      content = const GalleryMessage(
        title: 'Nothing to review yet',
        message: 'Photos and videos in your library will show up here.',
      );
    } else {
      content = _AllDone(
        review: _review,
        onShowMarked: () => DeletionQueueScreen.open(context, _review),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Playful doodles from the reference, behind the card.
        const Positioned(
          left: 22,
          top: 18,
          child: Doodle(
            kind: DoodleKind.confetti,
            color: AppColors.butter,
            size: 40,
            angle: -0.5,
          ),
        ),
        const Positioned(right: 18, top: 4, child: _KeepTheGoodOnes()),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: content,
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.review,
    required this.onClose,
    required this.onShowMarked,
  });

  final ReviewController review;
  final VoidCallback onClose;
  final VoidCallback onShowMarked;

  @override
  Widget build(BuildContext context) {
    final total = review.totalCount;
    final position = (review.reviewedCount + 1).clamp(0, total);
    final more = review.hasMoreToLoad ? '+' : '';
    final counter = total == 0 ? '' : '$position of $total$more';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close review',
            onPressed: onClose,
          ),
          Expanded(
            child: Semantics(
              header: true,
              liveRegion: true,
              child: Column(
                children: [
                  Text(
                    'Review',
                    style: AppText.sectionTitle.copyWith(fontSize: 20),
                  ),
                  if (counter.isNotEmpty) Text(counter, style: AppText.caption),
                ],
              ),
            ),
          ),
          CircleIconButton(
            icon: Icons.auto_delete_outlined,
            tooltip: 'Marked for deletion',
            badgeCount: review.markedCount,
            onPressed: onShowMarked,
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Review progress',
      value: '${(value * 100).round()}%',
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.lavenderSoft,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: AppDurations.of(context, AppDurations.medium),
          curve: AppCurves.standard,
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hand-lettered "Keep the good ones" note from the reference.
class _KeepTheGoodOnes extends StatelessWidget {
  const _KeepTheGoodOnes();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: -0.12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Keep\nthe good\nones',
              textAlign: TextAlign.right,
              textScaler: TextScaler.noScaling,
              style: AppText.display.copyWith(
                fontSize: 17,
                height: 1.05,
                color: AppColors.primaryDeep,
              ),
            ),
            const Doodle(
              kind: DoodleKind.squiggle,
              color: AppColors.primary,
              size: 26,
              angle: -0.6,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.canDecide,
    required this.canUndo,
    required this.onDelete,
    required this.onUndo,
    required this.onKeep,
  });

  final bool canDecide;
  final bool canUndo;
  final VoidCallback onDelete;
  final VoidCallback onUndo;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ReviewActionButton(
          icon: Icons.delete_outline_rounded,
          label: 'Mark for deletion',
          background: AppColors.peachSoft,
          foreground: AppColors.deleteInk,
          onPressed: canDecide ? onDelete : null,
        ),
        ReviewActionButton(
          icon: Icons.undo_rounded,
          label: 'Undo',
          size: 58,
          background: AppColors.lavenderSoft,
          foreground: AppColors.primary,
          onPressed: canUndo ? onUndo : null,
        ),
        ReviewActionButton(
          icon: Icons.favorite_rounded,
          label: 'Keep',
          background: AppColors.mintSoft,
          foreground: AppColors.keepInk,
          onPressed: canDecide ? onKeep : null,
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Loading photos to review',
        child: AspectRatio(
          aspectRatio: 1 / 1.3,
          child: FractionallySizedBox(
            widthFactor: 0.8,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.lavenderSoft,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone({required this.review, required this.onShowMarked});

  final ReviewController review;
  final VoidCallback onShowMarked;

  @override
  Widget build(BuildContext context) {
    final marked = review.markedCount;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Doodle(
              kind: DoodleKind.starburst,
              color: AppColors.mint,
              size: 56,
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                'All caught up!',
                style: AppText.display.copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Kept ${review.keptCount} · Marked $marked for deletion',
              style: AppText.label,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Nothing has been deleted. You’ll be able to check the marked '
              'items before anything is removed.',
              style: AppText.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (marked > 0)
                  FilledButton(
                    onPressed: onShowMarked,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: const StadiumBorder(),
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text('See marked ($marked)'),
                  ),
                TextButton(
                  onPressed: review.startOver,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDeep,
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('Start over'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
