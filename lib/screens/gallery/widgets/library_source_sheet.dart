import 'package:flutter/material.dart';

import '../../../data/media/media_access.dart';
import '../../../state/gallery_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';

/// Bottom sheet (opened from the profile avatar) for switching between the
/// device library and the bundled demo photos.
Future<void> showLibrarySourceSheet(
  BuildContext context,
  GalleryController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.ivory,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (context) => _LibrarySourceSheet(controller: controller),
  );
}

class _LibrarySourceSheet extends StatelessWidget {
  const _LibrarySourceSheet({required this.controller});

  final GalleryController controller;

  String get _accessSummary => switch (controller.access) {
    MediaAccess.granted => 'Full access to your photo library.',
    MediaAccess.limited => 'Access to the photos you selected.',
    MediaAccess.notDetermined => 'Not connected yet.',
    MediaAccess.denied ||
    MediaAccess.permanentlyDenied => 'Photo access is turned off.',
    MediaAccess.restricted => 'Photo access is restricted on this device.',
    MediaAccess.unknown => 'Checking…',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Library', style: AppText.display.copyWith(fontSize: 28)),
            const SizedBox(height: AppSpacing.xs),
            Text(_accessSummary, style: AppText.body),
            const SizedBox(height: AppSpacing.lg),
            _SourceOption(
              icon: Icons.photo_library_rounded,
              title: 'My photo library',
              subtitle: 'Photos and videos on this device',
              selected: !controller.isShowingDemo,
              onTap: () {
                Navigator.pop(context);
                controller.useDeviceLibrary();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _SourceOption(
              icon: Icons.auto_awesome_rounded,
              title: 'Demo photos',
              subtitle: 'Bundled sample photos, great for trying things out',
              selected: controller.isShowingDemo,
              onTap: () {
                Navigator.pop(context);
                controller.useDemoMedia();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.lavenderSoft : AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.label),
                      Text(subtitle, style: AppText.caption),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
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
