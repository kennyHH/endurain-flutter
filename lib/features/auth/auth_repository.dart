import 'package:endurain/core/models/identity_provider.dart';
import 'package:endurain/core/models/server_settings.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/server_settings_service.dart';
import 'package:endurain/core/services/sso_service.dart';

class AuthRepository {
  const AuthRepository({
    required AuthService authService,
    required SsoService ssoService,
    required ServerSettingsService serverSettingsService,
  }) : _authService = authService,
       _ssoService = ssoService,
       _serverSettingsService = serverSettingsService;

  final AuthService _authService;
  final SsoService _ssoService;
  final ServerSettingsService _serverSettingsService;

  Future<ServerSettings> getServerSettings(String serverUrl) {
    return _serverSettingsService.getServerSettings(serverUrl: serverUrl);
  }

  Future<List<IdentityProvider>> getEnabledProviders(String serverUrl) {
    return _ssoService.getEnabledProviders(serverUrl: serverUrl);
  }

  Future<String> initiateSsoLogin(
    IdentityProvider provider, {
    required String serverUrl,
  }) {
    return _ssoService.initiateOAuth(provider.slug, serverUrl: serverUrl);
  }

  Future<AuthResult> exchangeSsoSessionForTokens(String sessionId) {
    return _ssoService.exchangeSessionForTokens(sessionId);
  }

  Future<AuthResult> login({
    required String username,
    required String password,
    required String serverUrl,
  }) {
    return _authService.login(username, password, serverUrl: serverUrl);
  }

  Future<AuthResult> verifyMfa({
    required String username,
    required String mfaCode,
  }) {
    return _authService.verifyMfa(username, mfaCode);
  }

  void clearSsoPkce() {
    _ssoService.clearPkce();
  }
}
