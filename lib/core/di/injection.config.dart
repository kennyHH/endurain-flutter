// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:http/http.dart' as _i519;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/auth/controllers/login_controller.dart' as _i1020;
import '../../features/settings/controllers/settings_controller.dart' as _i335;
import '../database/app_database.dart' as _i982;
import '../error_handling/error_handler_service.dart' as _i1038;
import '../services/activity_repository.dart' as _i689;
import '../services/activity_upload_service.dart' as _i647;
import '../services/api_client.dart' as _i933;
import '../services/api_request_executor.dart' as _i104;
import '../services/audio_feedback_service.dart' as _i464;
import '../services/auth_service.dart' as _i745;
import '../services/bluetooth_sensor_service.dart' as _i947;
import '../services/gpx_exporter.dart' as _i55;
import '../services/location_service.dart' as _i669;
import '../services/map_tiles/tile_manager_service.dart' as _i763;
import '../services/power_management_service.dart' as _i949;
import '../services/secure_storage_service.dart' as _i535;
import '../services/server_settings_service.dart' as _i753;
import '../services/sso_service.dart' as _i853;
import '../services/tracking_session_engine.dart' as _i685;
import '../services/upload_queue/upload_queue_service.dart' as _i107;
import 'third_party_module.dart' as _i811;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final thirdPartyModule = _$ThirdPartyModule();
    gh.singleton<_i982.AppDatabase>(() => _i982.AppDatabase());
    gh.singleton<_i519.Client>(() => thirdPartyModule.httpClient);
    gh.singleton<Duration>(() => thirdPartyModule.defaultTimeout);
    gh.singleton<_i1038.ErrorHandlerService>(
      () => _i1038.ErrorHandlerService(),
    );
    gh.singleton<_i947.BluetoothSensorService>(
      () => _i947.BluetoothSensorService(),
    );
    gh.singleton<_i55.GpxExporter>(() => _i55.GpxExporter());
    gh.singleton<_i669.LocationService>(() => _i669.LocationService());
    gh.singleton<_i763.TileManagerService>(() => _i763.TileManagerService());
    gh.singleton<_i949.PowerManagementService>(
      () => _i949.PowerManagementService(),
    );
    gh.singleton<_i535.SecureStorageService>(
      () => _i535.SecureStorageService(),
    );
    gh.singleton<_i107.UploadQueueService>(() => _i107.UploadQueueService());
    gh.singleton<bool>(
      () => thirdPartyModule.phaseADiagnostics,
      instanceName: 'phaseADiagnostics',
    );
    gh.singleton<_i689.ActivityRepository>(
      () =>
          _i689.PersistentActivityRepository(database: gh<_i982.AppDatabase>()),
    );
    gh.singleton<_i685.PositionStreamProvider>(
      () => _i685.LocationServicePositionStreamProvider(
        gh<_i669.LocationService>(),
      ),
    );
    gh.singleton<bool>(
      () => thirdPartyModule.phaseBDistanceConsistency,
      instanceName: 'phaseBDistanceConsistency',
    );
    gh.singleton<_i104.ApiRequestExecutor>(
      () => _i104.ApiRequestExecutor(
        gh<_i519.Client>(),
        defaultTimeout: gh<Duration>(),
      ),
    );
    gh.singleton<_i745.AuthService>(
      () => _i745.AuthService(
        storage: gh<_i535.SecureStorageService>(),
        requestExecutor: gh<_i104.ApiRequestExecutor>(),
      ),
    );
    gh.singleton<_i753.ServerSettingsService>(
      () => _i753.ServerSettingsService(
        storage: gh<_i535.SecureStorageService>(),
        requestExecutor: gh<_i104.ApiRequestExecutor>(),
      ),
    );
    gh.singleton<_i853.SsoService>(
      () => _i853.SsoService(
        storage: gh<_i535.SecureStorageService>(),
        requestExecutor: gh<_i104.ApiRequestExecutor>(),
      ),
    );
    gh.singleton<_i464.AudioFeedbackService>(
      () => _i464.AudioFeedbackService(gh<_i535.SecureStorageService>()),
    );
    gh.singleton<_i933.ApiClient>(
      () => _i933.ApiClient(
        storage: gh<_i535.SecureStorageService>(),
        authService: gh<_i745.AuthService>(),
        requestExecutor: gh<_i104.ApiRequestExecutor>(),
      ),
    );
    gh.factory<_i1020.LoginController>(
      () => _i1020.LoginController(
        gh<_i745.AuthService>(),
        gh<_i853.SsoService>(),
        gh<_i753.ServerSettingsService>(),
      ),
    );
    gh.singleton<_i335.SettingsController>(
      () => _i335.SettingsController(
        gh<_i535.SecureStorageService>(),
        gh<_i464.AudioFeedbackService>(),
        gh<_i669.LocationService>(),
      ),
    );
    gh.singleton<_i685.TrackingSessionEngine>(
      () => _i685.TrackingSessionEngine(
        locationService: gh<_i669.LocationService>(),
        activityRepository: gh<_i689.ActivityRepository>(),
        audioService: gh<_i464.AudioFeedbackService>(),
        bluetoothService: gh<_i947.BluetoothSensorService>(),
        positionStreamProvider: gh<_i685.PositionStreamProvider>(),
        enablePhaseADiagnostics: gh<bool>(instanceName: 'phaseADiagnostics'),
        enablePhaseBDistanceConsistency: gh<bool>(
          instanceName: 'phaseBDistanceConsistency',
        ),
      ),
    );
    gh.singleton<_i647.ActivityUploadService>(
      () => _i647.ActivityUploadService(
        apiClient: gh<_i933.ApiClient>(),
        storage: gh<_i535.SecureStorageService>(),
        authService: gh<_i745.AuthService>(),
        gpxExporter: gh<_i55.GpxExporter>(),
        queueService: gh<_i107.UploadQueueService>(),
      ),
    );
    return this;
  }
}

class _$ThirdPartyModule extends _i811.ThirdPartyModule {}
