import 'dart:io';

import 'package:flutter/foundation.dart';

/// Platform utility functions
class PlatformUtils {
  @visibleForTesting
  static bool? debugIsApplePlatformOverride;

  @visibleForTesting
  static bool? debugIsMobileOverride;

  @visibleForTesting
  static void debugResetOverrides() {
    debugIsApplePlatformOverride = null;
    debugIsMobileOverride = null;
  }

  /// Check if the current platform is iOS or macOS
  static bool get isApplePlatform =>
      debugIsApplePlatformOverride ?? (Platform.isIOS || Platform.isMacOS);

  /// Check if the current platform is mobile (iOS or Android)
  static bool get isMobile =>
      debugIsMobileOverride ?? (Platform.isIOS || Platform.isAndroid);
}
