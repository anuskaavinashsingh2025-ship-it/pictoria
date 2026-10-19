import 'package:flutter/material.dart';

import '../../data/media/media_filters.dart';
import '../../data/media/media_repository.dart';
import '../../state/deletion_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'widgets/deletion_widgets.dart';

/// The explicit "are you sure?" step, then the honest result.
///
/// Deletion only starts when the user taps Continue here, and the platform
/// then shows its own system confirmation on top.
class ConfirmDeletionScreen extends StatelessWidget {
  const ConfirmDeletionScreen({super.key, required this.controller});

  final DeletionController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final phase = controller.phase;
        final busy = phase == DeletionPhase.deleting;
        return PopScope(
          // While the system is deleting, leaving would hide the outcome.
          canPop: !busy,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) controller.acknowledgeResult();
          },
          child: Scaffold(
            backgroundColor: AppColors.cream,
            body: SafeArea(
              child: AnimatedSwitcher(
                duration: AppDurations.of(context, AppDurations.medium),
                child: switch (phase) {
                  DeletionPhase.deleting => const _Waiting(),
                  DeletionPhase.finished => _ResultView(controller: controller),
                  _ => _Confirm(controller: controller),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// What will happen, in plain words, for this platform and item count.
String explanationFor(DeletionMode mode, int count) {
  final one = count == 1;
  final it = one ? 'It' : 'They';
  final itLower = one ? 'it' : 'they';
  return switch (mode) {
    DeletionMode.recentlyDeleted =>
      '$it’ll be removed from your iPhone’s photo library — and from your '
          'other devices if iCloud Photos is on. $it '
          '${one ? 'stays' : 'stay'} in “Recently Deleted” for 30 days, and '
          'storage is only freed after that. Your iPhone will ask you to '
          'confirm.',
    DeletionMode.trash =>
      '$it’ll be removed from your device’s photo library and moved to the '
          'system trash, where $itLower ${one ? 'stays' : 'stay'} for about '
          '30 days before Android removes ${one ? 'it' : 'them'} for good. '
          'Storage is only freed after that. Your device will ask you to '
          'confirm.',
    DeletionMode.permanent =>
      '$it’ll be permanently deleted from your device’s photo library. This '
          'can’t be undone.',
    DeletionMode.unsupported =>
      '${one ? 'This item' : 'These items'} can’t be deleted.',
  };
}

class _Confirm extends StatelessWidget {
  const _Confirm({required this.controller});

  final DeletionController controller;

  @override
  Widget build(BuildContext context) {
    final count = controller.selectedCount;
    final items = count == 1 ? 'item' : 'items';
    final size = describeSize(
      controller.selectedBytes,
      controller.unknownSizeCount,
    );

    return _Layout(
      key: const ValueKey('confirm'),
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.deleteInk,
      tint: AppColors.peachSoft,
      title: 'Delete $count $items?',
      subtitle: 'Estimated size: $size',
      body: [
        Text(explanationFor(controller.mode, count), style: AppText.body),
        const SizedBox(height: AppSpacing.lg),
        const NoticeCard(
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.deleteInk,
          tint: AppColors.peachSoft,
          message:
              'This changes your device’s photo library, not just Pictora.',
        ),
      ],
      actions: [
        DestructiveButton(
          label: 'Continue',
          onPressed: controller.canDelete ? controller.deleteSelected : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        _SecondaryButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('waiting'),
      child: Semantics(
        liveRegion: true,
        label: 'Waiting for your device to confirm the deletion',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.deleteInk),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Waiting for your confirmation…',
                style: AppText.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your device will show its own prompt. Nothing is removed '
                'unless you approve it there.',
                style: AppText.body,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.controller});

  final DeletionController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.lastResult!;
    final deleted = result.deletedIds.length;
    final failed = result.failedIds.length;
    final missing = result.missingIds.length;
    final requested = controller.lastRequestedCount;
    String plural(int n) => n == 1 ? 'item' : 'items';

    void done() {
      controller.acknowledgeResult();
      Navigator.of(context).maybePop();
    }

    final missingNote = missing == 0
        ? null
        : '$missing ${plural(missing)} had already been removed from your '
              'device.';

    final (
      IconData icon,
      Color color,
      Color tint,
      String title,
      String body,
    ) = switch (result.status) {
      DeletionStatus.success => (
        Icons.check_circle_rounded,
        AppColors.keepInk,
        AppColors.mintSoft,
        _successTitle(result.mode, deleted, plural(deleted)),
        _successBody(result.mode, controller.lastDeletedBytes, deleted),
      ),
      DeletionStatus.partial => (
        Icons.incomplete_circle_rounded,
        AppColors.primaryDeep,
        AppColors.butterSoft,
        'Deleted $deleted of $requested ${plural(requested)}',
        '$failed ${plural(failed)} couldn’t be deleted and '
            '${failed == 1 ? 'is' : 'are'} still in your queue, so you can '
            'try again later.',
      ),
      DeletionStatus.cancelled => (
        Icons.do_not_disturb_on_outlined,
        AppColors.primaryDeep,
        AppColors.lavenderSoft,
        'Nothing was deleted',
        'The deletion wasn’t confirmed. Your $requested '
            '${plural(requested)} ${requested == 1 ? 'is' : 'are'} still '
            'marked and waiting in your queue.',
      ),
      DeletionStatus.permissionDenied => (
        Icons.lock_outline_rounded,
        AppColors.deleteInk,
        AppColors.peachSoft,
        'Pictora needs photo access',
        'Nothing was deleted. Allow Pictora to access your photos in '
            'Settings, then try again. Your items are still in the queue.',
      ),
      DeletionStatus.failed => (
        Icons.error_outline_rounded,
        AppColors.deleteInk,
        AppColors.peachSoft,
        'Something went wrong',
        'Your device couldn’t complete the deletion. Nothing more was '
            'removed and your items are still in the queue. Please try '
            'again.',
      ),
    };

    return _Layout(
      key: ValueKey(result.status),
      icon: icon,
      iconColor: color,
      tint: tint,
      title: title,
      body: [
        Text(body, style: AppText.body),
        if (missingNote != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(missingNote, style: AppText.body),
        ],
      ],
      actions: [
        if (result.status == DeletionStatus.permissionDenied) ...[
          FilledButton(
            onPressed: controller.gallery.openSettings,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 52),
              shape: const StadiumBorder(),
            ),
            child: const Text('Open Settings'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _SecondaryButton(label: 'Done', onPressed: done, emphasized: true),
      ],
    );
  }

  static String _successTitle(DeletionMode mode, int n, String items) =>
      switch (mode) {
        DeletionMode.recentlyDeleted => 'Moved $n $items to Recently Deleted',
        DeletionMode.trash => 'Moved $n $items to the trash',
        _ => 'Deleted $n $items',
      };

  /// Only claims freed space when the platform deleted permanently and the
  /// sizes are known.
  static String _successBody(DeletionMode mode, int bytes, int count) {
    final it = count == 1 ? 'It' : 'They';
    final itLower = count == 1 ? 'it' : 'they';
    return switch (mode) {
      DeletionMode.recentlyDeleted =>
        '$it’ll be removed for good after 30 days. Storage is freed once '
            '$itLower leave${count == 1 ? 's' : ''} Recently Deleted.',
      DeletionMode.trash =>
        '$it’ll be removed for good after about 30 days. Storage is freed '
            'once the trash is emptied.',
      _ =>
        bytes > 0
            ? 'About ${formatFileSize(bytes)} of storage was freed.'
            : count == 1
            ? 'It’s been removed from your device.'
            : 'They’ve been removed from your device.',
    };
  }
}

/// Shared scrollable layout: icon, title, body, actions pinned at bottom.
class _Layout extends StatelessWidget {
  const _Layout({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.tint,
    required this.title,
    required this.body,
    required this.actions,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color tint;
  final String title;
  final String? subtitle;
  final List<Widget> body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 44),
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    title,
                    style: AppText.display.copyWith(fontSize: 32),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: AppText.label),
                ],
                const SizedBox(height: AppSpacing.lg),
                ...body,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: actions),
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDeep,
          backgroundColor: emphasized ? AppColors.lavenderSoft : null,
          side: BorderSide(
            color: emphasized ? AppColors.lavenderSoft : AppColors.lavender,
          ),
          minimumSize: const Size(0, 52),
          shape: const StadiumBorder(),
          textStyle: AppText.label.copyWith(fontSize: 16),
        ),
        child: Text(label),
      ),
    );
  }
}
