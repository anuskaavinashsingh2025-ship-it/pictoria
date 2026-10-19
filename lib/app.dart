import 'package:flutter/material.dart';

import 'data/media/media_repository.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'theme/app_theme.dart';

/// Root widget: sets up the theme and opens onboarding first.
///
/// Onboarding is shown on every launch for now; remembering that it was
/// completed will come with local storage in a later milestone. Onboarding
/// never asks for photo access — the Gallery asks when the user chooses to
/// connect their library.
class PictoraApp extends StatelessWidget {
  const PictoraApp({super.key, this.deviceRepository});

  /// Overrides the device library (used by tests). Null means the real one.
  final MediaRepository? deviceRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pictora',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: OnboardingScreen(deviceRepository: deviceRepository),
    );
  }
}
