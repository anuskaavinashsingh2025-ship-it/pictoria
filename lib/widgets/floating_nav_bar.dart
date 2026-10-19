import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// One destination in the [FloatingNavBar].
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// A rounded, floating bottom navigation bar.
///
/// The middle destination is shown as a raised purple circle, like the
/// reference design; the outer ones get a soft lavender pill when selected.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  }) : assert(destinations.length == 3);

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double _barHeight = 74;
  static const double _centerSize = 62;
  static const double _centerLift = 22;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            // Extra height above the bar keeps the raised button tappable.
            child: SizedBox(
              height: _barHeight + _centerLift,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    height: _barHeight,
                    decoration: BoxDecoration(
                      color: AppColors.ivory,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      boxShadow: AppShadows.soft,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Expanded(child: _sideItem(0)),
                        const SizedBox(width: _centerSize + 24),
                        Expanded(child: _sideItem(2)),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: _CenterItem(
                      destination: destinations[1],
                      selected: selectedIndex == 1,
                      size: _centerSize,
                      onTap: () => onSelected(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sideItem(int index) {
    return _SideItem(
      destination: destinations[index],
      selected: selectedIndex == index,
      onTap: () => onSelected(index),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Center(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: AnimatedContainer(
            duration: AppDurations.of(context, AppDurations.medium),
            curve: AppCurves.standard,
            width: 84,
            height: 58,
            decoration: BoxDecoration(
              color: selected ? AppColors.lavenderSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(height: 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: AppText.navLabel.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterItem extends StatelessWidget {
  const _CenterItem({
    required this.destination,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = AppDurations.of(context, AppDurations.medium);
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.06 : 1,
              duration: duration,
              curve: AppCurves.standard,
              child: AnimatedContainer(
                duration: duration,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.lavender : AppColors.ivory,
                    width: 4,
                  ),
                  boxShadow: AppShadows.glow,
                ),
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              textScaler: TextScaler.noScaling,
              style: AppText.navLabel.copyWith(
                color: selected ? AppColors.primary : AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
