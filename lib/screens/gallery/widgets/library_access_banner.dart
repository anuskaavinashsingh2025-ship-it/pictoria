import 'package:flutter/material.dart';

import '../../../data/media/media_access.dart';
import '../../../state/gallery_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';

/// What the banner should say for the current access state.
class _BannerContent {
  const _BannerContent({
    required this.icon,
    required this.title,
    required this.message,
    required this.tint,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tint;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
}

/// A friendly card above the grid explaining photo access, with the next
/// useful action (connect, try again, open Settings, manage selection).
///
/// Returns an empty box when there is nothing to say (full access).
class LibraryAccessBanner extends StatelessWidget {
  const LibraryAccessBanner({super.key, required this.controller});

  final GalleryController controller;

  _BannerContent? _contentFor(GalleryController c) {
    if (c.isShowingDemo) {
      return switch (c.access) {
        MediaAccess.unknown => null,
        MediaAccess.notDetermined => _BannerContent(
          icon: Icons.photo_library_outlined,
          title: 'Bring in your own photos',
          message:
              "You're looking at demo photos. Connect your library to browse "
              'your photos and videos — they never leave your device.',
          tint: AppColors.lavenderSoft,
          primaryLabel: 'Connect library',
          onPrimary: c.connectLibrary,
        ),
        MediaAccess.denied => _BannerContent(
          icon: Icons.lock_outline_rounded,
          title: 'Photo access is off',
          message:
              'Pictora needs your permission to show your photos. You can '
              'ask again, or turn it on in Settings.',
          tint: AppColors.peachSoft,
          primaryLabel: 'Try again',
          onPrimary: c.connectLibrary,
          secondaryLabel: 'Open Settings',
          onSecondary: c.openSettings,
        ),
        MediaAccess.permanentlyDenied => _BannerContent(
          icon: Icons.lock_outline_rounded,
          title: 'Photo access is off',
          message:
              'To see your photos, open Settings and allow Pictora to access '
              'Photos. Until then, enjoy the demo photos.',
          tint: AppColors.peachSoft,
          primaryLabel: 'Open Settings',
          onPrimary: c.openSettings,
        ),
        MediaAccess.restricted => const _BannerContent(
          icon: Icons.block_rounded,
          title: 'Photo access is restricted',
          message:
              "This device doesn't allow photo access (for example because of "
              'Screen Time or a work profile). You can keep exploring the '
              'demo photos.',
          tint: AppColors.butterSoft,
        ),
        MediaAccess.granted || MediaAccess.limited => _BannerContent(
          icon: Icons.auto_awesome_rounded,
          title: 'Showing demo photos',
          message: 'Your own library is connected and ready whenever you are.',
          tint: AppColors.mintSoft,
          primaryLabel: 'Show my library',
          onPrimary: c.useDeviceLibrary,
        ),
      };
    }

    if (c.access == MediaAccess.limited) {
      return _BannerContent(
        icon: Icons.photo_size_select_actual_outlined,
        title: 'Showing selected photos',
        message:
            "You've shared some of your photos with Pictora. Add more, or "
            'allow full access in Settings.',
        tint: AppColors.butterSoft,
        primaryLabel: 'Manage selection',
        onPrimary: c.manageLimitedSelection,
        secondaryLabel: 'Allow all',
        onSecondary: c.openSettings,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final content = _contentFor(controller);
    return AnimatedSize(
      duration: AppDurations.of(context, AppDurations.medium),
      curve: AppCurves.standard,
      alignment: Alignment.topCenter,
      child: content == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.lg,
                AppSpacing.screen,
                0,
              ),
              child: _BannerCard(content: content),
            ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.content});

  final _BannerContent content;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: content.tint,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.ivory,
                  shape: BoxShape.circle,
                ),
                child: Icon(content.icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(content.title, style: AppText.label),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      content.message,
                      style: AppText.body.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (content.primaryLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton(
                  onPressed: content.onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text(content.primaryLabel!),
                ),
                if (content.secondaryLabel != null)
                  TextButton(
                    onPressed: content.onSecondary,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryDeep,
                      shape: const StadiumBorder(),
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(content.secondaryLabel!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
