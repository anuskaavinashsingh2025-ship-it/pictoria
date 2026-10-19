import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'doodles.dart';

/// The "pictora" logotype: serif name plus two little sparkles.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 30});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: AppStrings.appName,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.appName,
            style: AppText.wordmark.copyWith(fontSize: fontSize),
          ),
          const SizedBox(width: 3),
          SizedBox(
            width: fontSize * 0.7,
            height: fontSize * 0.9,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Doodle(
                    kind: DoodleKind.sparkle,
                    color: AppColors.peach,
                    size: fontSize * 0.42,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: fontSize * 0.12,
                  child: Doodle(
                    kind: DoodleKind.sparkle,
                    color: AppColors.rose.withValues(alpha: 0.75),
                    size: fontSize * 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
