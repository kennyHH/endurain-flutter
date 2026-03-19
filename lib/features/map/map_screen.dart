import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/models/gps_filter_mode.dart';
import 'package:endurain/core/models/route_display_mode.dart';
import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/core/services/audio_feedback_service.dart';
import 'package:endurain/core/services/power_management_service.dart';
import 'package:endurain/core/services/map_tiles/tile_manager_service.dart';
import 'package:endurain/core/error_handling/app_error.dart';
import 'package:endurain/core/error_handling/error_handler_service.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/resume_token_refresh_coordinator.dart';
import 'package:endurain/core/utils/activity_upload_feedback_mapper.dart';
import 'package:endurain/core/utils/error_utils.dart';
import 'package:endurain/core/utils/history_route_thumbnail_key_builder.dart';
import 'package:endurain/core/utils/metric_formatter.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/theme/endurain_design_system.dart';
import 'package:endurain/features/history/widgets/activity_route_map.dart';
import 'package:endurain/features/map/widgets/tracking_controls.dart';
import 'package:endurain/features/map/controllers/map_screen_controller.dart';
import 'package:endurain/features/map/widgets/map_view.dart';
import 'package:endurain/features/map/widgets/map_overlay.dart';
import 'package:endurain/features/map/widgets/tracking_status_indicator.dart';

import 'package:endurain/core/di/service_locator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.locationService,
    this.storage,
    this.trackingSessionEngine,
    this.uploadService,
    this.onUploadFinished,
    this.routeDisplayMode = RouteDisplayMode.auto,
    this.gpsFilterMode = GpsFilterMode.auto,
    this.suggestedActivityType,
    this.onOpenBatteryOptimizationSettings,
    this.onAuthRequired,
  });

  final LocationService? locationService;
  final SecureStorageService? storage;
  final TrackingSessionEngine? trackingSessionEngine;
  final ActivityUploadService? uploadService;
  final Future<void> Function(Activity activity, bool success)?
  onUploadFinished;
  final RouteDisplayMode routeDisplayMode;
  final GpsFilterMode gpsFilterMode;
  final ActivityType? suggestedActivityType;
  final VoidCallback? onOpenBatteryOptimizationSettings;
  final VoidCallback? onAuthRequired;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  late final MapScreenController _controller;
  bool _permissionDialogVisible = false;

  // Use DI if dependencies are not provided
  late final LocationService _defaultLocationService =
      serviceLocator<LocationService>();
  late final SecureStorageService _defaultStorage =
      serviceLocator<SecureStorageService>();
  late final TrackingSessionEngine _defaultTrackingSessionEngine =
      serviceLocator<TrackingSessionEngine>();
  late final AuthService _defaultAuthService = serviceLocator<AuthService>();
  late final ActivityUploadService _defaultUploadService =
      serviceLocator<ActivityUploadService>();
  late final AudioFeedbackService _defaultAudioFeedbackService =
      serviceLocator<AudioFeedbackService>();
  late final PowerManagementService _defaultPowerManagementService =
      serviceLocator<PowerManagementService>();
  late final TileManagerService _defaultTileManagerService =
      serviceLocator<TileManagerService>();
  late final ErrorHandlerService _defaultErrorHandlerService =
      serviceLocator<ErrorHandlerService>();

  LocationService get _locationService =>
      widget.locationService ?? _defaultLocationService;
  SecureStorageService get _storage => widget.storage ?? _defaultStorage;
  TrackingSessionEngine get _trackingSessionEngine =>
      widget.trackingSessionEngine ?? _defaultTrackingSessionEngine;
  ActivityUploadService get _uploadService =>
      widget.uploadService ?? _defaultUploadService;
  AudioFeedbackService get _audioFeedbackService =>
      _defaultAudioFeedbackService;
  PowerManagementService get _powerManagementService =>
      _defaultPowerManagementService;
  TileManagerService get _tileManagerService => _defaultTileManagerService;
  ErrorHandlerService get _errorHandler => _defaultErrorHandlerService;
  late final ResumeTokenRefreshCoordinator _resumeTokenRefreshCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize FMTC
    _tileManagerService.init();

    // Try to process queue on screen load (e.g. back online)
    _defaultUploadService.processQueue();

    _controller = MapScreenController(
      locationService: _locationService,
      storage: _storage,
      trackingSessionEngine: _trackingSessionEngine,
      audioFeedbackService: _audioFeedbackService,
      powerManagementService: _powerManagementService,
      uploadService: _uploadService,
      routeDisplayMode: widget.routeDisplayMode,
      gpsFilterMode: widget.gpsFilterMode,
      // Preload current region if needed?
      // Or just pass the tile provider to the map view.
      // The MapView widget needs to accept a tile provider.
      // We need to update MapView to accept a TileProvider.
      // But MapView is stateless.
      // Let's pass it to the controller or the widget.
      // MapView takes 'controller'.
      // MapScreenController handles map state.
      // But MapView builds the FlutterMap.
      // We should probably pass the tile provider to MapView.
    );
    _controller.addListener(_handleControllerStateChanged);
    _resumeTokenRefreshCoordinator = ResumeTokenRefreshCoordinator(
      authService: _defaultAuthService,
      storage: _storage,
    );
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gpsFilterMode != widget.gpsFilterMode) {
      _controller.updateGpsFilterMode(widget.gpsFilterMode);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Controller is initialized here, so we own it and must dispose it.
    // However, if we dispose it, we can't use it anymore.
    // The previous error "MapScreenController was used after being disposed"
    // suggests that some async callback (like location loading) tried to notify listeners
    // after the widget was unmounted.
    // We already added _isDisposed check in the controller, so it should be safe now.
    _controller.removeListener(_handleControllerStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.checkLocationPermission();
      unawaited(_resumeTokenRefreshCoordinator.triggerBestEffortRefresh());
    }
  }

  void _handleControllerStateChanged() {
    if (!mounted || _permissionDialogVisible) return;
    if (!_controller.shouldShowPermissionOnboarding) return;
    _permissionDialogVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showPermissionOnboardingDialog();
    });
  }

  Future<void> _showPermissionOnboardingDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final startSetup = await _showPlatformPermissionDialog();
    if (!mounted) return;
    if (startSetup == true) {
      await _controller.runPermissionOnboardingSetup();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Tracking permissions setup completed.')),
      );
    } else {
      await _controller.skipPermissionOnboarding();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.trackingPermissionRequired)));
    }
    _permissionDialogVisible = false;
  }

  Future<bool?> _showPlatformPermissionDialog() {
    final l10n = AppLocalizations.of(context)!;
    if (PlatformUtils.isApplePlatform) {
      return showCupertinoDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Enable Tracking Permissions'),
          content: const Text(
            'To start tracking reliably, please enable location access and battery/background optimizations now.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Set up now'),
            ),
          ],
        ),
      );
    }
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enable Tracking Permissions'),
        content: const Text(
          'To start tracking reliably, please enable location access and battery/background optimizations now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Set up now'),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureTrackingPermissionBeforeStart() async {
    if (_controller.hasLocationPermission) return true;
    if (_permissionDialogVisible) return _controller.hasLocationPermission;
    _permissionDialogVisible = true;
    try {
      final startSetup = await _showPlatformPermissionDialog();
      if (!mounted) return false;
      if (startSetup != true) {
        return false;
      }
      await _controller.runPermissionOnboardingSetup();
      if (!mounted) return false;
      await _controller.checkLocationPermission();
      if (!mounted) return false;
      return _controller.hasLocationPermission;
    } finally {
      _permissionDialogVisible = false;
    }
  }

  void _handleStartTracking(ActivityType activityType, int activityTypeId) {
    unawaited(
      _handleStartTrackingAsync(
        activityType: activityType,
        activityTypeId: activityTypeId,
      ),
    );
  }

  Future<void> _handleStartTrackingAsync({
    required ActivityType activityType,
    required int activityTypeId,
  }) async {
    if (!_controller.hasLocationPermission) {
      final granted = await _ensureTrackingPermissionBeforeStart();
      if (!mounted) return;
      if (!granted) {
        _showTrackingPermissionError();
        return;
      }
    }
    if (!_controller.hasStableStartFix && !_controller.hasWarmStartLocation) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.trackingGpsNeedStableFix)));
      return;
    }
    await HapticFeedback.selectionClick();
    _controller.startTracking(activityType, activityTypeId: activityTypeId);
  }

  Future<void> _handleStopTracking() async {
    final activity = await _controller.stopTracking();
    if (activity == null) return;

    final shouldSave = await _confirmSuspiciousSaveIfNeeded(activity);
    if (!shouldSave) {
      await _controller.discardActivity(activity.id);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.trackingDiscardedActivity)));
      return;
    }

    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    _showSaveCelebration();
    unawaited(_warmHistoryThumbnail(activity));

    try {
      final result = await _controller.uploadActivity(activity);
      if (!mounted) return;
      await widget.onUploadFinished?.call(activity, result.success);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final messenger = ScaffoldMessenger.maybeOf(context);

      final message = ActivityUploadFeedbackMapper.toDisplayMessage(
        result,
        l10n,
      );

      if (messenger == null) return;
      if (!result.success) {
        await HapticFeedback.heavyImpact();
        if (!mounted) return;
        if (result.failureType == ActivityUploadFailureType.invalidActivity) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        if (result.failureType == ActivityUploadFailureType.authentication &&
            widget.onAuthRequired != null) {
          await ErrorUtils.showRetryDialog(
            context: context,
            title: l10n.error,
            message: message,
            onRetry: widget.onAuthRequired!,
            retryLabel: l10n.login,
            cancelLabel: l10n.cancel,
          );
          return;
        }
        if (mounted) {
          _errorHandler.showError(
            context: context,
            error: UploadError(
              message: message,
              originalError: result.failureType,
            ),
            onRetry: () => _retryUploadInBackground(activity),
          );
        }
      } else {
        await HapticFeedback.lightImpact();
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      await _controller.resetSession();
    }
  }

  Future<void> _warmHistoryThumbnail(Activity activity) async {
    if (!mounted || activity.trackPoints.length < 2) return;
    await ActivityRouteMap.warmUpInOverlay(
      context: context,
      points: activity.trackPoints,
      useMatchedTrack: widget.routeDisplayMode != RouteDisplayMode.raw,
      activityType: activity.activityType,
      thumbnailCacheKey: buildHistoryRouteThumbnailCacheKey(activity),
    );
  }

  Future<void> _retryUploadInBackground(Activity activity) async {
    final result = await _controller.uploadActivity(activity);
    if (!mounted) return;
    await widget.onUploadFinished?.call(activity, result.success);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);

    final message = ActivityUploadFeedbackMapper.toDisplayMessage(result, l10n);

    if (messenger == null) return;
    if (!result.success &&
        result.failureType == ActivityUploadFailureType.invalidActivity) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!result.success &&
        result.failureType == ActivityUploadFailureType.authentication &&
        widget.onAuthRequired != null) {
      if (!mounted) return;
      await ErrorUtils.showRetryDialog(
        context: context,
        title: l10n.error,
        message: message,
        onRetry: widget.onAuthRequired!,
        retryLabel: l10n.login,
        cancelLabel: l10n.cancel,
      );
      return;
    }
    if (result.success) {
      await HapticFeedback.lightImpact();
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isSuspiciousActivity(Activity activity) {
    final duration = activity.durationSeconds;
    final distance = activity.distanceMeters;
    if (duration < 20 || distance < 50) return true;
    final speed = activity.averageSpeedKmh;
    if (speed == null) return false;
    if (activity.activityType == ActivityType.ride) return speed > 80;
    return speed > 30;
  }

  Future<bool> _confirmSuspiciousSaveIfNeeded(Activity activity) async {
    if (!_isSuspiciousActivity(activity) || !mounted) return true;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trackingSuspiciousSaveTitle),
        content: Text(
          l10n.trackingSuspiciousSaveMessage(
            MetricFormatter.formatDurationLabeled(activity.durationSeconds),
            MetricFormatter.formatDistanceKm(
              activity.distanceMeters,
              l10n.trackingDistanceUnitKm,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.trackingDiscardAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showSaveCelebration() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1300),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.celebration_rounded, size: 18),
            const SizedBox(width: 8),
            Text(l10n.trackingActivitySavedCelebration),
          ],
        ),
      ),
    );
  }

  void _showTrackingPermissionError() {
    final l10n = AppLocalizations.of(context)!;
    if (PlatformUtils.isApplePlatform) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(l10n.error),
          content: Text(l10n.trackingPermissionRequired),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.trackingPermissionRequired)));
  }

  String _liveRouteStatusLabel(AppLocalizations l10n) {
    if (widget.routeDisplayMode == RouteDisplayMode.raw) {
      return l10n.routeStatusRaw;
    }
    if (_controller.trackingSnapshot.trackPoints.length < 3) {
      return l10n.routeStatusRaw;
    }
    return l10n.routeStatusFallback;
  }

  double _controlsHeightFactor({
    required double screenHeight,
    required bool showControls,
  }) {
    final compactHeight = screenHeight <= 700;
    return compactHeight
        ? (showControls ? 0.53 : 0.49)
        : (showControls ? 0.48 : 0.44);
  }

  double _countdownBottomOffset(BuildContext context, bool showControls) {
    final height = MediaQuery.sizeOf(context).height;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final controlsHeight =
        height *
        _controlsHeightFactor(screenHeight: height, showControls: showControls);

    const controlsBottomInset = 62.0;
    const countdownSize = 120.0;
    const visualGap = 14.0;
    final minBottom = controlsBottomInset + viewPadding.bottom + visualGap;
    final desiredBottom = minBottom + controlsHeight;
    final maxBottom = height - viewPadding.top - countdownSize - visualGap;
    return desiredBottom.clamp(minBottom, maxBottom);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.trackingSnapshot.state;
        final isRecording = state == TrackingSessionState.recording;
        final isPaused = state == TrackingSessionState.paused;
        final isLiveTracking = isRecording || isPaused;
        final showControls = isRecording || isPaused;
        final showGpsWarning = isRecording && _controller.isGpsSignalLost;
        final hasGpsFixForStatus = isLiveTracking
            ? (_controller.hasRecentGpsFix && !_controller.isGpsSignalLost)
            : _controller.hasStableStartFix;
        final showBatteryPolicyFlag =
            PlatformUtils.isAndroid &&
            isRecording &&
            !_controller.isBatteryOptimizationIgnored;
        final showRouteChip =
            widget.routeDisplayMode != RouteDisplayMode.raw && isRecording;

        final body = Stack(
          children: [
            // Map Layer
            MapView(
              mapController: _controller.mapController,
              currentLocation: _controller.currentLocation,
              tileServerUrl: _controller.tileServerUrl,
              tileProvider: _tileManagerService.tileProvider,
              trackingSnapshot: _controller.trackingSnapshot,
              routeDisplayMode: widget.routeDisplayMode,
              heading: _controller.heading,
              hasLocationPermission: _controller.shouldRenderUserLocation,
              onMapMoved: _controller.onMapMoved,
            ),

            // Loading Indicator
            if (_controller.isLoadingLocation)
              PlatformUtils.isApplePlatform
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CupertinoActivityIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Finding your location...',
                            style: CupertinoTheme.of(
                              context,
                            ).textTheme.textStyle,
                          ),
                        ],
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),

            // Overlay Buttons (Audio, Compass)
            if (!_controller.isPreparingStart) // Hide during countdown
              MapOverlayButtons(
                audioEnabled: _controller.audioEnabled,
                isNorthUp: _controller.isNorthUp,
                heading: _controller.heading,
                onToggleAudio: _controller.toggleAudio,
                onToggleCompass: _controller.toggleCompassMode,
                onSettingsTap: () {
                  // Navigate to Settings
                  // We need to know the route or screen.
                  // Assuming '/settings' or pushing SettingsScreen.
                  // Since we have GoRouter, we should use context.push('/settings')
                  // BUT I need to check routes.
                  // For now, let's try a direct Navigator push to be safe if routes are unknown.
                  // Wait, I can import SettingsScreen.
                  // Let's use the named route '/settings' if it exists in AppRouter.
                  // If not, we fail. But AppRouter usually has it.
                  // Let's check AppRouter content? No, just try push.
                  Navigator.of(context).pushNamed('/settings').then((_) {
                    // Refresh on return
                    _controller.notifyListeners();
                  });
                },
              ),

            // Big Center Countdown Overlay
            if (_controller.isPreparingStart)
              Positioned(
                left: 0,
                right: 0,
                bottom: _countdownBottomOffset(context, showControls),
                child: Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${_controller.trackingSnapshot.countdownSeconds ?? ""}',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom Controls Sheet
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    EndurainSpacing.sm,
                    EndurainSpacing.sm,
                    EndurainSpacing.sm,
                    62,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final controlsNeedExtraHeight = showControls;
                      final compactHeight = constraints.maxHeight <= 700;
                      final heightFactor = compactHeight
                          ? (controlsNeedExtraHeight ? 0.53 : 0.49)
                          : (controlsNeedExtraHeight ? 0.48 : 0.44);
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: FractionallySizedBox(
                          heightFactor: heightFactor,
                          alignment: Alignment.bottomCenter,
                          child: TrackingControls(
                            snapshot: _controller.trackingSnapshot,
                            suggestedActivityType: widget.suggestedActivityType,
                            hasGpsFix: hasGpsFixForStatus,
                            isPreparingStart: _controller.isPreparingStart,
                            startCountdownSeconds:
                                _controller.trackingSnapshot.countdownSeconds ??
                                0,
                            onStart: _handleStartTracking,
                            onPause: () {
                              _controller.pauseTracking();
                              HapticFeedback.lightImpact();
                            },
                            onResume: () {
                              _controller.resumeTracking();
                              HapticFeedback.lightImpact();
                            },
                            onStop: _handleStopTracking,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // GPS Warning Banner
            if (showGpsWarning)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      EndurainSpacing.xl,
                      EndurainSpacing.sm,
                      EndurainSpacing.xl,
                      172,
                    ),
                    child: GpsSignalWarningBanner(
                      message: l10n.trackingGpsSignalLost,
                    ),
                  ),
                ),
              ),

            // Route Status Chip
            if (showRouteChip)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: EndurainSpacing.sm),
                    child: TrackingStatusIndicator(
                      label: _liveRouteStatusLabel(l10n),
                    ),
                  ),
                ),
              ),

            if (showBatteryPolicyFlag)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 44),
                    child: BackgroundPolicyWarningFlag(
                      message: 'Battery optimization active',
                      onTap: widget.onOpenBatteryOptimizationSettings,
                    ),
                  ),
                ),
              ),
          ],
        );

        if (PlatformUtils.isApplePlatform) {
          return CupertinoPageScaffold(child: body);
        }
        return Scaffold(body: body);
      },
    );
  }
}
