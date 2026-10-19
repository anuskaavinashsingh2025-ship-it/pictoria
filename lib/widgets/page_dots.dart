import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Page indicator: the active page is a wider purple pill.
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final duration = AppDurations.of(context, AppDurations.medium);
    return Semantics(
      label: 'Page ${current + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: duration,
              curve: AppCurves.standard,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == current ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current ? AppColors.primary : AppColors.lavender,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
        ],
      ),
    );
  }
}
