import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/utils/platform_utils.dart';

class MapStateController extends ChangeNotifier {
  MapStateController({
    required LocationService locationService,
    required SecureStorageService storage,
    Stream<CompassEvent>? compassEvents,
  }) : _locationService = locationService,
       _storage = storage,
       _compassEvents = compassEvents;

  final LocationService _locationService;
  final SecureStorageService _storage;
  final Stream<CompassEvent>? _compassEvents;

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;
  bool _initialized = false;
  bool _isDisposed = false;

  LatLng currentLocation = const LatLng(
    MapConstants.defaultLatitude,
    MapConstants.defaultLongitude,
  );
  String tileServerUrl = MapConstants.defaultTileServerUrl;
  bool isLoadingLocation = false;
  bool hasLocationPermission = false;
  bool isLocationLocked = true;
  double heading = 0.0;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    await Future.wait([_loadSettings(), _loadUserLocation()]);
    if (_isDisposed) {
      return;
    }
    _startCompassUpdates();
  }

  Future<void> _loadSettings() async {
    final tileUrl = await _storage.getTileServerUrl();
    if (tileUrl != null && tileUrl.isNotEmpty) {
      tileServerUrl = tileUrl;
      _notifyListeners();
    }
  }

  Future<void> _loadUserLocation() async {
    isLoadingLocation = true;
    _notifyListeners();

    final position = await _locationService.getCurrentPosition();

    if (_isDisposed) {
      return;
    }

    if (position != null) {
      currentLocation = LatLng(position.latitude, position.longitude);
      hasLocationPermission = true;
      isLoadingLocation = false;
      _notifyListeners();
      _startPositionUpdates();
      return;
    }

    hasLocationPermission = false;
    isLoadingLocation = false;
    _notifyListeners();
  }

  void _startCompassUpdates() {
    if (!PlatformUtils.isMobile) {
      return;
    }

    final events = _compassEvents ?? FlutterCompass.events;
    _compassSubscription = events?.listen((event) {
      final nextHeading = event.heading;
      if (nextHeading == null) {
        return;
      }
      heading = nextHeading;
      _notifyListeners();
    });
  }

  void _startPositionUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = _locationService.getPositionStream().listen((
      position,
    ) {
      currentLocation = LatLng(position.latitude, position.longitude);
      _notifyListeners();
    });
  }

  void toggleLocationLock() {
    isLocationLocked = !isLocationLocked;
    _notifyListeners();
  }

  void unlockLocation() {
    if (!isLocationLocked) {
      return;
    }
    isLocationLocked = false;
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
