import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// The big purple call-to-action.
///
/// Shows a round arrow button, and smoothly widens into a labelled pill when
/// [label] is provided (used for the final "Open Gallery" step).
class GradientCtaButton extends StatelessWidget {
  const GradientCtaButton({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
    this.label,
  });

  final VoidCallback onPressed;
  final String semanticLabel;
  final String? label;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final duration = AppDurations.of(context, AppDurations.slow);
    final expanded = label != null;

    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
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
              // AnimatedSize smoothly animates (and clips) the width change
              // between the round arrow and the labelled pill.
              child: AnimatedSize(
                duration: duration,
                curve: AppCurves.emphasized,
                child: SizedBox(
                  height: _size,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: expanded ? 26 : (_size - 28) / 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (expanded) ...[
                          Flexible(
                            child: Text(
                              label!,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: AppText.label.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
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
