import 'package:flutter/material.dart';

import '../../../data/media/media_filters.dart';
import '../../../data/media/media_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';

/// What the Filters sheet returns when the user taps "Apply filters".
typedef GalleryFilterChoice = ({MediaTypeFilter type, GalleryOptions options});

/// Size steps for the range slider (bytes). The last step means "no limit".
const sizeStops = <int?>[
  0,
  100 * 1000,
  1000 * 1000,
  5 * 1000 * 1000,
  10 * 1000 * 1000,
  50 * 1000 * 1000,
  100 * 1000 * 1000,
  500 * 1000 * 1000,
  1000 * 1000 * 1000,
  null, // no upper limit
];

int _indexForMin(int? bytes) {
  if (bytes == null) return 0;
  final index = sizeStops.indexOf(bytes);
  return index < 0 ? 0 : index;
}

int _indexForMax(int? bytes) {
  if (bytes == null) return sizeStops.length - 1;
  final index = sizeStops.indexOf(bytes);
  return index < 0 ? sizeStops.length - 1 : index;
}

SizeRange _rangeFor(int minIndex, int maxIndex) => SizeRange(
  minBytes: minIndex == 0 ? null : sizeStops[minIndex],
  maxBytes: maxIndex == sizeStops.length - 1 ? null : sizeStops[maxIndex],
);

String _stopLabel(int index) {
  final bytes = sizeStops[index];
  if (bytes == null) return 'No limit';
  if (bytes == 0) return '0';
  return formatFileSize(bytes);
}

/// Opens the Filters sheet. Returns the chosen settings, or null if the
/// sheet was closed without applying.
Future<GalleryFilterChoice?> showGalleryFiltersSheet(
  BuildContext context, {
  required MediaTypeFilter type,
  required GalleryOptions options,
}) {
  return showModalBottomSheet<GalleryFilterChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.ivory,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (context) => _FiltersSheet(type: type, options: options),
  );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.type, required this.options});

  final MediaTypeFilter type;
  final GalleryOptions options;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late MediaTypeFilter _type = widget.type;
  late GallerySort _sort = widget.options.sort;
  late RangeValues _size = RangeValues(
    _indexForMin(widget.options.size.minBytes).toDouble(),
    _indexForMax(widget.options.size.maxBytes).toDouble(),
  );

  SizeRange get _range => _rangeFor(_size.start.round(), _size.end.round());

  void _reset() => setState(() {
    _type = MediaTypeFilter.all;
    _sort = GallerySort.newest;
    _size = RangeValues(0, (sizeStops.length - 1).toDouble());
  });

  void _apply() => Navigator.of(context).pop<GalleryFilterChoice>((
    type: _type,
    options: GalleryOptions(sort: _sort, size: _range),
  ));

  @override
  Widget build(BuildContext context) {
    final needsSizes = _sort.isSizeBased || _range.isActive;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Filters',
                        style: AppText.display.copyWith(fontSize: 30),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close filters',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.ink),
                  ),
                ],
              ),
              const _Divider(),
              const _SectionTitle('Media type'),
              _PillWrap(
                children: [
                  for (final (type, label) in [
                    (MediaTypeFilter.all, 'All'),
                    (MediaTypeFilter.photos, 'Photos'),
                    (MediaTypeFilter.videos, 'Videos'),
                  ])
                    _OptionPill(
                      label: label,
                      group: 'Media type',
                      selected: _type == type,
                      onTap: () => setState(() => _type = type),
                    ),
                ],
              ),
              const _SectionTitle('Sort by'),
              _PillWrap(
                children: [
                  for (final sort in GallerySort.values)
                    _OptionPill(
                      label: sort.label,
                      group: 'Sort by',
                      icon: switch (sort) {
                        GallerySort.newest => Icons.arrow_downward_rounded,
                        GallerySort.oldest => Icons.arrow_upward_rounded,
                        _ => Icons.straighten_rounded,
                      },
                      selected: _sort == sort,
                      onTap: () => setState(() => _sort = sort),
                    ),
                ],
              ),
              const _SectionTitle('File size'),
              Row(
                children: [
                  Text(_stopLabel(_size.start.round()), style: AppText.caption),
                  const Spacer(),
                  Text(_range.label, style: AppText.label),
                  const Spacer(),
                  Text(_stopLabel(_size.end.round()), style: AppText.caption),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.lavenderSoft,
                  thumbColor: AppColors.ivory,
                  overlayColor: AppColors.primaryGlow,
                  rangeThumbShape: const RoundRangeSliderThumbShape(
                    enabledThumbRadius: 11,
                    elevation: 3,
                  ),
                  trackHeight: 6,
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: RangeSlider(
                  values: _size,
                  min: 0,
                  max: (sizeStops.length - 1).toDouble(),
                  divisions: sizeStops.length - 1,
                  semanticFormatterCallback: (value) =>
                      _stopLabel(value.round()),
                  onChanged: (values) {
                    // Keep at least one step between the two handles.
                    if (values.end - values.start < 1) return;
                    setState(() => _size = values);
                  },
                ),
              ),
              if (needsSizes)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Size sorting and filters measure each photo and video '
                    'once, which can take a moment for large libraries. '
                    'Items whose size can’t be read are listed as “Size '
                    'unknown”.',
                    style: AppText.caption,
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              _ApplyButton(onPressed: _apply),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: _reset,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDeep,
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('Reset to default'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Divider(color: AppColors.sand, height: 1),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
    child: Semantics(
      header: true,
      child: Text(text, style: AppText.sectionTitle),
    ),
  );
}

class _PillWrap extends StatelessWidget {
  const _PillWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: children,
  );
}

/// A selectable pill matching the Gallery's filter chips.
class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.label,
    required this.group,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final String group;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: '$group: $label',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: AppDurations.of(context, AppDurations.fast),
            constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.ivory,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.sand,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.label.copyWith(color: foreground)),
                if (icon != null && selected) ...[
                  const SizedBox(width: 6),
                  Icon(icon, size: 16, color: foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Apply filters',
      onTap: onPressed,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: AppShadows.glow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: Center(
                child: Text(
                  'Apply filters',
                  style: AppText.label.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Removable chips summarising non-default sort and size settings, shown
/// under the Gallery's filter chips.
class ActiveFiltersRow extends StatelessWidget {
  const ActiveFiltersRow({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final GalleryOptions options;
  final ValueChanged<GalleryOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isDefault) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (options.sort != GallerySort.newest)
            _RemovableChip(
              label: 'Sort: ${options.sort.label}',
              onRemove: () =>
                  onChanged(options.copyWith(sort: GallerySort.newest)),
            ),
          if (options.size.isActive)
            _RemovableChip(
              label: 'Size: ${options.size.label}',
              onRemove: () => onChanged(options.copyWith(size: SizeRange.any)),
            ),
          TextButton(
            onPressed: () => onChanged(GalleryOptions.defaults),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryDeep,
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. Remove',
      onTap: onRemove,
      excludeSemantics: true,
      child: Material(
        color: AppColors.lavenderSoft,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onRemove,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppText.label.copyWith(color: AppColors.primaryDeep),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.primaryDeep,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
