import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class MapOverlayButtons extends StatelessWidget {
  const MapOverlayButtons({
    super.key,
    required this.audioEnabled,
    required this.isNorthUp,
    required this.heading,
    required this.onToggleAudio,
    required this.onToggleCompass,
    this.onSettingsTap, // Added callback
  });

  final bool audioEnabled;
  final bool isNorthUp;
  final double heading;
  final VoidCallback onToggleAudio;
  final VoidCallback onToggleCompass;
  final VoidCallback? onSettingsTap; // Optional callback

  @override
  Widget build(BuildContext context) {
    // If not visible (e.g. countdown or loading), we might want to hide these buttons.
    // For now, keep them visible.

    // Overlay for Countdown
    // This is passed as a separate widget usually, but we can check if we should show a big countdown here?
    // No, MapScreen handles the layers.
    // Let's assume MapScreen will overlay a countdown widget if needed.

    if (PlatformUtils.isApplePlatform) {
      return Stack(
        children: [
          // Audio Button (Top Left)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(
                  LocationMarkerConstants.buttonOuterPadding,
                ),
                child: CupertinoButton.filled(
                  color: const Color(0xCC16212B),
                  padding: const EdgeInsets.all(
                    LocationMarkerConstants.buttonInnerPadding,
                  ),
                  onPressed: onToggleAudio,
                  child: Tooltip(
                    message: audioEnabled
                        ? 'Mute Voice Coach'
                        : 'Enable Voice Coach',
                    child: Icon(
                      audioEnabled
                          ? CupertinoIcons.volume_up
                          : CupertinoIcons.volume_off,
                      color: const Color(0xFF1FC8B6),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Compass Button (Top Right)
          // Also adding Settings Button below Compass for testing
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(
                      LocationMarkerConstants.buttonOuterPadding,
                    ),
                    child: CupertinoButton.filled(
                      color: const Color(0xCC16212B),
                      padding: const EdgeInsets.all(
                        LocationMarkerConstants.buttonInnerPadding,
                      ),
                      onPressed: onToggleCompass,
                      child: Tooltip(
                        message: isNorthUp
                            ? 'Map is North Up. Tap to follow heading.'
                            : 'Map follows heading. Tap to lock North Up.',
                        child: isNorthUp
                            ? const Icon(
                                CupertinoIcons.compass,
                                color: Color(0xFF1FC8B6),
                              )
                            : Transform.rotate(
                                angle: (heading * math.pi / 180) * -1,
                                child: const Icon(
                                  CupertinoIcons.location_north_fill,
                                  color: Color(0xFF1FC8B6),
                                ),
                              ),
                      ),
                    ),
                  ),
                  // Settings Button (Temporary entry point for testing)
                  Padding(
                    padding: const EdgeInsets.only(
                      right: LocationMarkerConstants.buttonOuterPadding,
                      bottom: LocationMarkerConstants.buttonOuterPadding,
                    ),
                    child: CupertinoButton.filled(
                      color: const Color(0xCC16212B),
                      padding: const EdgeInsets.all(
                        LocationMarkerConstants.buttonInnerPadding,
                      ),
                      onPressed: onSettingsTap ?? () {
                        debugPrint('Settings tapped (no callback provided)');
                      },
                      child: const Icon(
                        CupertinoIcons.settings,
                        color: Color(0xFF1FC8B6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Material Style
    return Stack(
      children: [
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(
                LocationMarkerConstants.buttonOuterPadding,
              ),
              child: FloatingActionButton.small(
                heroTag: 'audio_toggle',
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh,
                foregroundColor: audioEnabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                onPressed: onToggleAudio,
                tooltip: audioEnabled
                    ? 'Mute Voice Coach'
                    : 'Enable Voice Coach',
                child: Icon(audioEnabled ? Icons.volume_up : Icons.volume_off),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(
                LocationMarkerConstants.buttonOuterPadding,
              ),
              child: FloatingActionButton.small(
                heroTag: 'compass_btn',
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh,
                foregroundColor: Theme.of(context).colorScheme.primary,
                onPressed: onToggleCompass,
                tooltip: isNorthUp ? 'Map is North Up' : 'Follow Heading',
                child: isNorthUp
                    ? const Icon(Icons.explore)
                    : Transform.rotate(
                        angle: (heading * math.pi / 180) * -1,
                        child: const Icon(Icons.navigation),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
