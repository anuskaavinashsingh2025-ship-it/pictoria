/// How much of the device photo library Pictora may read.
enum MediaAccess {
  /// We haven't checked yet (the app just started).
  unknown,

  /// The user hasn't been asked yet.
  notDetermined,

  /// Full access to the photo library.
  granted,

  /// Access only to the photos and videos the user picked
  /// (iOS 14+ and Android 14+).
  limited,

  /// The user said no, but we may ask again (Android only).
  denied,

  /// The user said no and the system won't show the prompt again; only
  /// the Settings app can change it.
  permanentlyDenied,

  /// Blocked by device policy (e.g. Screen Time or parental controls).
  restricted;

  bool get canReadMedia => this == granted || this == limited;

  /// Whether tapping "Connect" can show the system permission prompt.
  bool get canRequest => this == notDetermined || this == denied;

  /// Whether sending the user to Settings is the useful next step.
  bool get shouldOfferSettings =>
      this == denied || this == permanentlyDenied || this == limited;
}
