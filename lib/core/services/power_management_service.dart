import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:endurain/core/utils/platform_utils.dart';

@singleton
class PowerManagementService {
  /// Request the system to ignore battery optimizations for this app.
  /// This is crucial for long-running background tracking on Android.
  Future<bool> requestBatteryExemption() async {
    if (!PlatformUtils.isAndroid) return true;

    // Check if already ignored
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) {
      return true;
    }

    // Request permission (opens system dialog or settings)
    final result = await Permission.ignoreBatteryOptimizations.request();
    return result.isGranted;
  }

  /// Check if battery optimization is currently ignored.
  Future<bool> isBatteryOptimizationIgnored() async {
    if (!PlatformUtils.isAndroid) return true;
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Enable wakelock to keep the screen on.
  /// Useful for "Map Mode" or active navigation.
  Future<void> enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('[PowerManagement] Failed to enable wakelock: $e');
    }
  }

  /// Disable wakelock, allowing screen to sleep.
  Future<void> disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('[PowerManagement] Failed to disable wakelock: $e');
    }
  }

  /// Check if wakelock is currently enabled.
  Future<bool> isWakelockEnabled() async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      return false;
    }
  }
}
