import 'package:flutter/material.dart';

import '../../../data/media/media_filters.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';

export '../../../data/media/media_filters.dart' show GalleryFilter;

/// A horizontally scrolling row of rounded filter pills.
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final GalleryFilter selected;
  final ValueChanged<GalleryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Don't clip, so the selected chip's soft glow isn't cut off.
      clipBehavior: Clip.none,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Row(
        children: [
          for (final filter in GalleryFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterPill(
                filter: filter,
                selected: filter == selected,
                onTap: () => onSelected(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final GalleryFilter filter;
  final bool selected;
  final VoidCallback onTap;

  /// Only Favorites gets an icon: a heart, matching the tile hearts.
  IconData? get _icon =>
      filter == GalleryFilter.favorites ? Icons.favorite_rounded : null;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.ink;

    return Semantics(
      button: true,
      selected: selected,
      label: '${filter.label} filter',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: AppDurations.of(context, AppDurations.medium),
            curve: AppCurves.standard,
            constraints: const BoxConstraints(minHeight: 44, minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.ivory,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: selected ? AppShadows.glow : null,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.sand,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_icon != null) ...[
                  Icon(
                    _icon,
                    size: 16,
                    color: selected ? Colors.white : AppColors.rose,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  filter.label,
                  style: AppText.label.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
