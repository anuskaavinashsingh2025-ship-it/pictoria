import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Total and free space on the device, as reported by the operating system.
class DeviceStorage {
  const DeviceStorage({required this.totalBytes, required this.availableBytes});

  final int totalBytes;
  final int availableBytes;

  int get usedBytes => (totalBytes - availableBytes).clamp(0, totalBytes);
  double get usedFraction => totalBytes == 0 ? 0 : usedBytes / totalBytes;
}

/// Tiny bridge to native code for facts plugins don't expose.
///
/// The native side lives in MainActivity.kt (Android) and AppDelegate.swift
/// (iOS). Every method returns null instead of throwing when unavailable.
class PlatformInfo {
  const PlatformInfo();

  static const _channel = MethodChannel('pictora/platform');

  /// The Android API level (e.g. 34), or null if unknown / not Android.
  Future<int?> androidSdkInt() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _channel.invokeMethod<int>('androidSdkInt');
    } catch (error) {
      debugPrint('Could not read Android version: $error');
      return null;
    }
  }

  /// Real device storage figures, or null if the platform can't say.
  Future<DeviceStorage?> deviceStorage() async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>(
        'deviceStorage',
      );
      final total = map?['totalBytes'];
      final available = map?['availableBytes'];
      if (total is! int || available is! int || total <= 0) return null;
      return DeviceStorage(totalBytes: total, availableBytes: available);
    } catch (error) {
      debugPrint('Could not read device storage: $error');
      return null;
    }
  }
}
