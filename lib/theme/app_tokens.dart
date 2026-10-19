import 'package:flutter/material.dart';

/// Design tokens: the single source of truth for Pictora's look and feel.
///
/// Widgets should read colors, spacing, radii and durations from here instead
/// of hard-coding numbers, so the whole app can be restyled in one place.

/// Brand name in one place, so the working title is easy to change later.
abstract final class AppStrings {
  static const appName = 'pictora';
}

abstract final class AppColors {
  // Warm neutrals
  static const cream = Color(0xFFFBF6EF); // page background
  static const ivory = Color(0xFFFFFDF9); // cards, inputs, nav bar
  static const sand = Color(0xFFF1E9DE); // subtle borders / placeholders

  // Ink (text)
  static const ink = Color(0xFF1F1B3A); // headlines, primary text
  static const inkMuted = Color(0xFF6B6782); // secondary text (AA on cream)

  // Brand purple
  static const primary = Color(0xFF7458F2);
  static const primaryDeep = Color(0xFF5A41DE);
  static const primaryGlow = Color(0x557458F2);

  // Pastel accents
  static const lavender = Color(0xFFCFC7FA);
  static const lavenderSoft = Color(0xFFECE8FD);
  static const peach = Color(0xFFF7C6B0);
  static const peachSoft = Color(0xFFFCE6DB);
  static const mint = Color(0xFF8FDDB9);
  static const mintSoft = Color(0xFFD9F4E7);
  static const butter = Color(0xFFF4D774);
  static const butterSoft = Color(0xFFFBF0C9);
  static const rose = Color(0xFFEF7E92); // hearts / favorites

  // Review decisions (text/icons on the soft mint and peach surfaces).
  static const keepInk = Color(0xFF1F7A57); // ~4.5:1 on mintSoft
  static const deleteInk = Color(0xFFB23A3A); // ~4.9:1 on peachSoft

  // Storage chart.
  static const chartOther = Color(0xFFD6CEC4); // "everything else" slice
  static const chartTrack = Color(0xFFF0EAE2); // free space
  static const videoSlice = Color(0xFFF2A98C); // deeper peach for contrast

  static const shadow = Color(0x1A2B1F4D);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9C84FF), primary, primaryDeep],
  );
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal padding used by every screen.
  static const double screen = 20;

  /// Gap between photos in the gallery grid.
  static const double gridGap = 10;
}

abstract final class AppRadii {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 30;
  static const double pill = 999;
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const page = Duration(milliseconds: 450);

  /// Returns [duration], or zero when the user asked the OS to reduce motion.
  static Duration of(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}

abstract final class AppCurves {
  static const standard = Curves.easeOutCubic;
  static const emphasized = Curves.easeInOutCubicEmphasized;
}

abstract final class AppShadows {
  static const soft = [
    BoxShadow(color: AppColors.shadow, blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const card = [
    BoxShadow(color: Color(0x262B1F4D), blurRadius: 18, offset: Offset(0, 8)),
  ];

  static const glow = [
    BoxShadow(
      color: AppColors.primaryGlow,
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}
