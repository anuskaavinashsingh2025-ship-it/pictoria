import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../data/media/media_filters.dart';
import '../../../data/media/media_item.dart';
import '../../../state/review_controller.dart';
import '../../../theme/app_tokens.dart';
import 'review_buttons.dart';

/// Asks the stack to slide a card back in after Undo. [tick] changes every
/// time, so the same decision can be undone twice in a row.
typedef UndoEntry = ({int tick, ReviewDecision from});

/// The tilted photo card you drag left or right, with the next card peeking
/// out behind it and the floating KEEP / DELETE labels.
///
/// How it works:
///  * While dragging, the card simply follows the finger ([_drag]).
///  * On release, it either flies off screen (a decision) or springs back.
///  * Buttons call [SwipeCardStackState.flyOut] so they animate the same way.
///  * With "reduce motion" on, decisions apply instantly without flying.
class SwipeCardStack extends StatefulWidget {
  const SwipeCardStack({
    super.key,
    required this.current,
    required this.next,
    required this.imageFor,
    required this.onDecision,
    this.undoEntry,
  });

  final MediaItem current;
  final MediaItem? next;

  /// Returns a thumbnail about [pixelWidth] physical pixels wide.
  final ImageProvider Function(MediaItem item, int pixelWidth) imageFor;

  /// Called once the card has left the screen.
  final ValueChanged<ReviewDecision> onDecision;

  final UndoEntry? undoEntry;

  @override
  State<SwipeCardStack> createState() => SwipeCardStackState();
}

class SwipeCardStackState extends State<SwipeCardStack>
    with SingleTickerProviderStateMixin {
  /// How far the top card is currently moved from its resting place.
  Offset _drag = Offset.zero;

  late final AnimationController _animation;
  Animation<Offset>? _offsetTween;
  ReviewDecision? _pendingDecision;
  int? _handledUndoTick;

  /// Width of the area the stack lives in (set during layout).
  double _areaWidth = 400;

  /// Resting tilt of the top card, like the reference design.
  static const _restTilt = -0.05;

  double get _threshold => _areaWidth * 0.28;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  /// -1 … 1: how strongly the user is leaning towards delete or keep.
  double get _lean => (_drag.dx / _threshold).clamp(-1.0, 1.0);

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this)
      ..addListener(() {
        final tween = _offsetTween;
        if (tween != null) setState(() => _drag = tween.value);
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finishAnimation();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAnimateUndo());
  }

  @override
  void didUpdateWidget(SwipeCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.undoEntry?.tick != oldWidget.undoEntry?.tick) {
      _maybeAnimateUndo();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  bool get isAnimating => _animation.isAnimating;

  /// Animates the top card off screen, then reports [decision].
  void flyOut(ReviewDecision decision) {
    if (_animation.isAnimating) return;
    HapticFeedback.lightImpact();
    if (_reduceMotion) {
      _commit(decision);
      return;
    }
    final direction = decision == ReviewDecision.keep ? 1.0 : -1.0;
    _pendingDecision = decision;
    _runTo(
      Offset(direction * _areaWidth * 1.5, _drag.dy + 60),
      AppDurations.medium,
      Curves.easeInCubic,
    );
  }

  void _maybeAnimateUndo() {
    final entry = widget.undoEntry;
    if (!mounted || entry == null || entry.tick == _handledUndoTick) return;
    _handledUndoTick = entry.tick;
    if (_reduceMotion) return; // it simply reappears
    // Start off screen on the side it left from, then glide back in.
    final direction = entry.from == ReviewDecision.keep ? 1.0 : -1.0;
    _animation.stop();
    _pendingDecision = null;
    setState(() => _drag = Offset(direction * _areaWidth * 1.3, 40));
    _runTo(Offset.zero, AppDurations.slow, Curves.easeOutCubic);
  }

  void _runTo(Offset target, Duration duration, Curve curve) {
    _offsetTween = Tween(
      begin: _drag,
      end: target,
    ).animate(CurvedAnimation(parent: _animation, curve: curve));
    _animation
      ..duration = duration
      ..forward(from: 0);
  }

  void _finishAnimation() {
    final decision = _pendingDecision;
    _pendingDecision = null;
    _offsetTween = null;
    if (decision != null) _commit(decision);
  }

  void _commit(ReviewDecision decision) {
    // Reset first so the next card appears in the resting position on the
    // same frame the parent swaps it in.
    setState(() => _drag = Offset.zero);
    widget.onDecision(decision);
  }

  // --- Gestures --------------------------------------------------------------

  void _onPanUpdate(DragUpdateDetails details) {
    if (_animation.isAnimating) return;
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_animation.isAnimating) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_drag.dx > _threshold || velocity > 900) {
      flyOut(ReviewDecision.keep);
    } else if (_drag.dx < -_threshold || velocity < -900) {
      flyOut(ReviewDecision.delete);
    } else if (_reduceMotion) {
      setState(() => _drag = Offset.zero);
    } else {
      _runTo(Offset.zero, AppDurations.slow, Curves.easeOutBack);
    }
  }

  // --- Layout -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _areaWidth = constraints.maxWidth;
        // An oversized card: most of the width, but never taller than fits.
        var cardWidth = (constraints.maxWidth * 0.8).clamp(0.0, 440.0);
        var cardHeight = cardWidth * 1.3;
        if (cardHeight > constraints.maxHeight * 0.94) {
          cardHeight = constraints.maxHeight * 0.94;
          cardWidth = cardHeight / 1.3;
        }
        final pixelWidth = (cardWidth * MediaQuery.devicePixelRatioOf(context))
            .round();
        final lean = _lean;
        final dragTilt = _reduceMotion ? 0.0 : lean * 0.16;
        final restTilt = _reduceMotion ? 0.0 : _restTilt;
        final cardSize = Size(cardWidth, cardHeight);
        final next = widget.next;

        // Positions of the floating labels, relative to the card's right edge.
        final cardRight = (constraints.maxWidth - cardWidth) / 2;
        final cardTop = (constraints.maxHeight - cardHeight) / 2;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // The next card, peeking out behind and growing as you swipe.
            if (next != null)
              Transform.translate(
                offset: const Offset(-14, 10),
                child: Transform.rotate(
                  angle: restTilt * -0.6,
                  child: Transform.scale(
                    scale: 0.93 + 0.07 * lean.abs(),
                    child: _PhotoCard(
                      key: ValueKey('next-${next.id}'),
                      item: next,
                      size: cardSize,
                      image: widget.imageFor(next, pixelWidth),
                      dimmed: true,
                    ),
                  ),
                ),
              ),
            // The top card that follows your finger.
            Transform.translate(
              offset: _drag,
              child: Transform.rotate(
                angle: restTilt + dragTilt,
                child: GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Semantics(
                    label: _semanticLabel(widget.current),
                    hint:
                        'Swipe right to keep, or left to mark for deletion. '
                        'Or use the Keep and Delete buttons.',
                    customSemanticsActions: {
                      const CustomSemanticsAction(label: 'Keep'): () =>
                          flyOut(ReviewDecision.keep),
                      const CustomSemanticsAction(
                        label: 'Mark for deletion',
                      ): () =>
                          flyOut(ReviewDecision.delete),
                    },
                    child: _PhotoCard(
                      key: ValueKey('top-${widget.current.id}'),
                      item: widget.current,
                      size: cardSize,
                      image: widget.imageFor(widget.current, pixelWidth),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: (cardRight - 34).clamp(4.0, double.infinity),
              top: cardTop + cardHeight * 0.16,
              child: DecisionLabel(
                text: 'KEEP',
                icon: Icons.favorite_rounded,
                background: AppColors.mintSoft,
                foreground: AppColors.keepInk,
                emphasis: lean,
              ),
            ),
            Positioned(
              right: (cardRight - 44).clamp(4.0, double.infinity),
              top: cardTop + cardHeight * 0.66,
              child: DecisionLabel(
                text: 'DELETE',
                icon: Icons.delete_outline_rounded,
                background: AppColors.peachSoft,
                foreground: AppColors.deleteInk,
                emphasis: -lean,
              ),
            ),
          ],
        );
      },
    );
  }

  String _semanticLabel(MediaItem item) {
    final created = item.createdAt;
    final when = created == null
        ? ''
        : ', ${dayLabel(created, DateTime.now())}';
    final length = item.duration == null
        ? ''
        : ', ${formatDuration(item.duration!)} long';
    return '${item.accessibilityLabel}$when$length';
  }
}

/// The ivory-framed photo card itself.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    super.key,
    required this.item,
    required this.size,
    required this.image,
    this.dimmed = false,
  });

  final MediaItem item;
  final Size size;
  final ImageProvider image;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    const frame = 8.0;
    final created = item.createdAt;
    return Container(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.all(frame),
      decoration: BoxDecoration(
        color: AppColors.ivory,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E2B1F4D),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl - frame),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.sand,
              child: Image(
                image: image,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.inkMuted,
                    size: 40,
                  ),
                ),
              ),
            ),
            if (dimmed)
              ColoredBox(color: AppColors.cream.withValues(alpha: 0.25)),
            if (!dimmed)
              Positioned(
                left: 12,
                bottom: 12,
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      if (item.isVideo)
                        _Chip(
                          icon: Icons.play_arrow_rounded,
                          text: item.duration == null
                              ? 'Video'
                              : formatDuration(item.duration!),
                        ),
                      if (item.isVideo && created != null)
                        const SizedBox(width: 6),
                      if (created != null)
                        _Chip(text: dayLabel(created, DateTime.now())),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 6, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, color: Colors.white, size: 16),
          Text(
            text,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
