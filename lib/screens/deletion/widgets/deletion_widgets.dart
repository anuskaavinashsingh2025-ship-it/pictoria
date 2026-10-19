import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../data/media/media_filters.dart';
import '../../../data/review/review_record.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';

/// A soft tinted notice card (info, warning, success).
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.icon,
    required this.message,
    this.tint = AppColors.lavenderSoft,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final String message;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: AppText.body.copyWith(color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One marked photo/video in the deletion queue, with a selection circle,
/// thumbnail, date, type, size and a "put back in review" action.
class QueueRow extends StatelessWidget {
  const QueueRow({
    super.key,
    required this.record,
    required this.image,
    required this.selected,
    required this.sizeLabel,
    required this.enabled,
    required this.onToggle,
    required this.onRestore,
  });

  final ReviewRecord record;
  final ImageProvider image;
  final bool selected;
  final String sizeLabel;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final item = record.item;
    final created = item.createdAt;
    final when = created == null
        ? 'Undated'
        : dayLabel(created, DateTime.now());
    final kind = item.isVideo
        ? 'Video${item.duration == null ? '' : ' · ${formatDuration(item.duration!)}'}'
        : 'Photo';
    final title = item.title ?? (item.isVideo ? 'Video' : 'Photo');

    return Semantics(
      container: true,
      checked: selected,
      enabled: enabled,
      label: '$title, $when, $kind, $sizeLabel',
      hint: selected
          ? 'Selected for deletion. Double tap to deselect.'
          : 'Not selected. Double tap to select.',
      onTap: enabled ? onToggle : null,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Put back in review'): onRestore,
      },
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.ivory : AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: enabled ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                _SelectionCircle(selected: selected),
                const SizedBox(width: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Opacity(
                      opacity: selected ? 1 : 0.5,
                      child: Image(
                        image: image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.sand,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label,
                      ),
                      Text(when, style: AppText.caption),
                      Text('$kind · $sizeLabel', style: AppText.caption),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Put back in review',
                  onPressed: onRestore,
                  icon: const Icon(Icons.undo_rounded),
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.of(context, AppDurations.fast),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.deleteInk : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.deleteInk : AppColors.inkMuted,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

/// The red destructive pill button. Always clearly labelled.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.delete_outline_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, textAlign: TextAlign.center),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.deleteInk,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.sand,
          disabledForegroundColor: AppColors.inkMuted,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const StadiumBorder(),
          textStyle: AppText.label.copyWith(fontSize: 16),
        ),
      ),
    );
  }
}

/// Human description of a combined size, honest about unknown sizes.
String describeSize(int bytes, int unknownCount) {
  if (bytes == 0 && unknownCount > 0) return 'size not available';
  final base = 'about ${formatFileSize(bytes)}';
  return unknownCount == 0 ? base : '$base (+$unknownCount unknown)';
}
