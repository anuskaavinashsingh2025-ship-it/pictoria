import 'package:flutter/material.dart';

import '../../data/media/media_filters.dart';
import '../../data/media/media_repository.dart';
import '../../data/review/review_record.dart';
import '../../state/deletion_controller.dart';
import '../../state/review_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/doodles.dart';
import '../gallery/widgets/gallery_states.dart';
import '../review/widgets/review_buttons.dart';
import 'confirm_deletion_screen.dart';
import 'widgets/deletion_widgets.dart';

/// Lists everything marked for deletion. The user can deselect items, put
/// them back into review, and then move on to the confirmation screen.
/// Nothing is deleted from this screen.
class DeletionQueueScreen extends StatefulWidget {
  const DeletionQueueScreen({
    super.key,
    required this.review,
    this.autoConfirm = false,
  });

  final ReviewController review;

  /// Go straight on to the confirmation screen once the queue has been
  /// checked (used by "Continue to delete" on Insights). Cancel there
  /// returns to this queue, so nothing is ever deleted without the explicit
  /// Continue tap and the system prompt.
  final bool autoConfirm;

  static Future<void> open(
    BuildContext context,
    ReviewController review, {
    bool autoConfirm = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            DeletionQueueScreen(review: review, autoConfirm: autoConfirm),
      ),
    );
  }

  @override
  State<DeletionQueueScreen> createState() => _DeletionQueueScreenState();
}

class _DeletionQueueScreenState extends State<DeletionQueueScreen> {
  late final DeletionController _deletion;

  @override
  void initState() {
    super.initState();
    _deletion = DeletionController(review: widget.review);
    _start();
  }

  Future<void> _start() async {
    await _deletion.start();
    if (!mounted || !widget.autoConfirm) return;
    _openConfirmation();
  }

  @override
  void dispose() {
    _deletion.dispose();
    super.dispose();
  }

  void _openConfirmation() {
    if (!_deletion.canDelete) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ConfirmDeletionScreen(controller: _deletion),
      ),
    );
  }

  String _sizeLabel(ReviewRecord record) {
    final bytes = _deletion.sizeOf(record);
    if (bytes != null) return formatFileSize(bytes);
    return _deletion.isSizeUnavailable(record)
        ? 'size unknown'
        : 'checking size…';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _deletion,
          builder: (context, _) => Column(
            children: [
              _Header(onBack: () => Navigator.of(context).maybePop()),
              Expanded(child: _buildBody()),
              if (_deletion.phase != DeletionPhase.checking &&
                  _deletion.records.isNotEmpty)
                _BottomBar(deletion: _deletion, onDelete: _openConfirmation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_deletion.phase == DeletionPhase.checking) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: 'Checking your marked items',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),
              Text('Checking your marked items…', style: AppText.body),
            ],
          ),
        ),
      );
    }

    final notices = _notices();
    final records = _deletion.records;

    if (records.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          ...notices,
          const GalleryMessage(
            title: 'Nothing marked for deletion',
            message:
                'Swipe left in Review to mark photos and videos you no '
                'longer need. They’ll wait here until you decide.',
            doodle: DoodleKind.heart,
          ),
        ],
      );
    }

    final pixelWidth = (64 * MediaQuery.devicePixelRatioOf(context)).round();
    final allSelected = _deletion.selectedCount == records.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.lg,
      ),
      children: [
        ...notices,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    '${_deletion.selectedCount} of ${records.length} '
                    'selected · ${describeSize(_deletion.selectedBytes, _deletion.unknownSizeCount)}',
                    style: AppText.label,
                  ),
                ),
              ),
              TextButton(
                onPressed: allSelected
                    ? _deletion.selectNone
                    : _deletion.selectAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDeep,
                  minimumSize: const Size(0, 44),
                ),
                child: Text(allSelected ? 'Select none' : 'Select all'),
              ),
            ],
          ),
        ),
        for (final record in records)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: QueueRow(
              key: ValueKey(record.id),
              record: record,
              image: widget.review.gallery.thumbnailFor(
                record.item,
                pixelWidth: pixelWidth,
              ),
              selected: _deletion.isSelected(record),
              sizeLabel: _sizeLabel(record),
              enabled: _deletion.phase == DeletionPhase.ready,
              onToggle: () => _deletion.toggle(record),
              onRestore: () => widget.review.restoreToReview(record.item),
            ),
          ),
      ],
    );
  }

  List<Widget> _notices() {
    final widgets = <Widget>[];
    void add(Widget notice) => widgets
      ..add(notice)
      ..add(const SizedBox(height: AppSpacing.md));

    if (_deletion.mode == DeletionMode.unsupported && _deletion.isDemo) {
      add(
        const NoticeCard(
          icon: Icons.auto_awesome_rounded,
          message:
              'These are demo photos bundled with Pictora, so they can’t be '
              'deleted. Connect your photo library to clean up real photos.',
          tint: AppColors.butterSoft,
        ),
      );
    }
    if (_deletion.interruptedDeletedCount > 0 ||
        _deletion.interruptedRemainingCount > 0) {
      add(
        NoticeCard(
          icon: Icons.history_rounded,
          message:
              'Your last deletion was interrupted. '
              '${_count(_deletion.interruptedDeletedCount, 'item was', 'items were')} '
              'removed; ${_count(_deletion.interruptedRemainingCount, 'is', 'are')} '
              'still on your device and in this list.',
        ),
      );
    }
    if (_deletion.missingRemovedCount > 0) {
      add(
        NoticeCard(
          icon: Icons.info_outline_rounded,
          message:
              '${_count(_deletion.missingRemovedCount, 'item was', 'items were')} '
              'already gone from your device, so we took '
              '${_deletion.missingRemovedCount == 1 ? 'it' : 'them'} off this list.',
        ),
      );
    }
    return widgets;
  }

  static String _count(int n, String singular, String plural) =>
      '$n ${n == 1 ? singular : plural}';
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
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
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: onBack,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Marked for deletion',
                style: AppText.display.copyWith(fontSize: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.deletion, required this.onDelete});

  final DeletionController deletion;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final count = deletion.selectedCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.ivory,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DestructiveButton(
            label: count == 0
                ? 'Select items to delete'
                : 'Review deletion of $count ${count == 1 ? 'item' : 'items'}',
            onPressed: deletion.canDelete ? onDelete : null,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Nothing is deleted yet — you’ll confirm on the next screen.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
