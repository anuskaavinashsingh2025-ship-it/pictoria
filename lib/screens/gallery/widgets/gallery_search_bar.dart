import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';

/// Rounded "Find a memory…" search field plus a filter-options button.
class GallerySearchBar extends StatelessWidget {
  const GallerySearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onOptionsPressed,
    this.activeFilterCount = 0,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onOptionsPressed;

  /// Shown as a badge on the filter button when filters are active.
  final int activeFilterCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.ivory,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: AppShadows.soft,
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: AppText.label.copyWith(fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Find a memory…',
                hintStyle: AppText.body.copyWith(fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.inkMuted,
                ),
                // Rebuilds just the clear button when the text changes.
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.inkMuted,
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Semantics(
          button: true,
          label: activeFilterCount == 0
              ? 'Filters and sorting'
              : 'Filters and sorting, $activeFilterCount active',
          // Screen readers activate the button through this action.
          onTap: onOptionsPressed,
          excludeSemantics: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: activeFilterCount > 0
                    ? AppColors.primary
                    : AppColors.lavenderSoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: InkWell(
                  onTap: onOptionsPressed,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: Tooltip(
                      message: 'Filters and sorting',
                      child: Icon(
                        Icons.tune_rounded,
                        color: activeFilterCount > 0
                            ? Colors.white
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              if (activeFilterCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.peach,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$activeFilterCount',
                      textScaler: TextScaler.noScaling,
                      style: AppText.caption.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
