import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';

class MapStateController extends ChangeNotifier {
  MapStateController({
    required LocationService locationService,
    required SecureStorageService storage,
  }) : _locationService = locationService,
       _storage = storage;

  final LocationService _locationService;
  final SecureStorageService _storage;

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
      _updateHeading(position);
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

  void _startPositionUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = _locationService.getPositionStream().listen((
      position,
    ) {
      currentLocation = LatLng(position.latitude, position.longitude);
      _updateHeading(position);
      _notifyListeners();
    });
  }

  void _updateHeading(Position position) {
    if (position.heading.isNaN || position.heading < 0) {
      return;
    }
    heading = position.heading;
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
    _positionSubscription?.cancel();
    super.dispose();
  }
}
