import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/doodles.dart';

/// Soft placeholder tiles shown while the first page loads.
class GalleryLoadingSkeleton extends StatelessWidget {
  const GalleryLoadingSkeleton({super.key});

  static const _heights = [1.0, 1.4, 1.2, 1.3, 1.0, 1.5, 1.1, 1.0, 1.3];
  static const _colors = [
    AppColors.lavenderSoft,
    AppColors.peachSoft,
    AppColors.mintSoft,
    AppColors.butterSoft,
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your photos',
      liveRegion: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.xl,
          AppSpacing.screen,
          0,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const columns = 3;
            final width =
                (constraints.maxWidth - AppSpacing.gridGap * (columns - 1)) /
                columns;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: AppSpacing.gridGap),
                  Column(
                    children: [
                      for (var r = 0; r < 3; r++)
                        Container(
                          width: width,
                          height: width * _heights[c * 3 + r],
                          margin: const EdgeInsets.only(
                            bottom: AppSpacing.gridGap,
                          ),
                          decoration: BoxDecoration(
                            color: _colors[(c + r) % _colors.length],
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A centered illustration + message + optional actions, used for empty
/// and error states.
class GalleryMessage extends StatelessWidget {
  const GalleryMessage({
    super.key,
    required this.title,
    required this.message,
    this.doodle = DoodleKind.sparkle,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final DoodleKind doodle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        140, // room for the floating nav bar
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Doodle(kind: doodle, color: AppColors.lavender, size: 48),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppText.sectionTitle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(message, style: AppText.body, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 44),
              ),
              child: Text(actionLabel!),
            ),
          ],
          if (secondaryLabel != null)
            TextButton(
              onPressed: onSecondary,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDeep,
                minimumSize: const Size(0, 44),
              ),
              child: Text(secondaryLabel!),
            ),
        ],
      ),
    );
  }
}

/// The small row at the bottom of the grid while more pages load.
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text("Couldn't load more · Retry"),
          style: TextButton.styleFrom(foregroundColor: AppColors.primaryDeep),
        ),
      );
    }
    if (!isLoading) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
            semanticsLabel: 'Loading more photos',
          ),
        ),
      ),
    );
  }
}
