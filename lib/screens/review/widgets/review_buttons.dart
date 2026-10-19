import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';

/// A floating pill label such as "KEEP" or "DELETE" that grows and brightens
/// as the card is dragged towards it.
class DecisionLabel extends StatelessWidget {
  const DecisionLabel({
    super.key,
    required this.text,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.emphasis,
  });

  final String text;
  final IconData icon;
  final Color background;
  final Color foreground;

  /// -1 (dragging away) … 0 (resting) … 1 (dragging towards this label).
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    final towards = emphasis.clamp(0.0, 1.0);
    final away = (-emphasis).clamp(0.0, 1.0);
    return ExcludeSemantics(
      // The buttons below carry the accessible labels.
      child: Opacity(
        opacity: (0.92 - away * 0.6).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 1 + towards * 0.18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: AppShadows.soft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  text,
                  textScaler: TextScaler.noScaling,
                  style: AppText.label.copyWith(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A big round soft-colored button (Delete / Undo / Keep).
class ReviewActionButton extends StatelessWidget {
  const ReviewActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.size = 76,
  });

  final IconData icon;

  /// Spoken by screen readers and shown as a tooltip.
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.4,
          duration: AppDurations.of(context, AppDurations.fast),
          child: Material(
            color: background,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: foreground, size: size * 0.42),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small ivory circle icon button for the top bar.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: badgeCount > 0 ? '$tooltip, $badgeCount' : tooltip,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: AppColors.ivory,
              shape: const CircleBorder(),
              elevation: 0,
              shadowColor: AppColors.shadow,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(icon, color: AppColors.ink, size: 22),
                ),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.deleteInk,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '$badgeCount',
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
