import 'package:flutter/foundation.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/sso_service.dart';
import 'package:endurain/core/services/server_settings_service.dart';
import 'package:endurain/core/models/identity_provider.dart';
import 'package:endurain/core/models/server_settings.dart';
import 'package:injectable/injectable.dart';

@injectable
class LoginController extends ChangeNotifier {
  LoginController(
    this._authService,
    this._ssoService,
    this._serverSettingsService,
  );

  final AuthService _authService;
  final SsoService _ssoService;
  final ServerSettingsService _serverSettingsService;

  // State
  bool _isLoading = false;
  bool _isStep2 = false;
  bool _showMfaInput = false;
  bool _obscurePassword = true;
  
  ServerSettings? _serverSettings;
  List<IdentityProvider> _availableIdPs = [];
  String? _mfaUsername;
  
  Object? _error;
  bool _loginSuccess = false;

  // Getters
  bool get isLoading => _isLoading;
  bool get isStep2 => _isStep2;
  bool get showMfaInput => _showMfaInput;
  bool get obscurePassword => _obscurePassword;
  bool get localLoginEnabled => _serverSettings?.localLoginEnabled ?? true;
  ServerSettings? get serverSettings => _serverSettings;
  List<IdentityProvider> get availableIdPs => _availableIdPs;
  Object? get error => _error;
  bool get loginSuccess => _loginSuccess;

  // Actions
  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void resetStep2() {
    _isStep2 = false;
    _availableIdPs = [];
    _serverSettings = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Step 1: Check Server URL
  Future<void> checkServerUrl(String serverUrl) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final settings = await _serverSettingsService.getServerSettings(
        serverUrl: serverUrl,
      );
      _serverSettings = settings;

      if (settings.ssoEnabled) {
        try {
          _availableIdPs = await _ssoService.getEnabledProviders(serverUrl: serverUrl);
        } catch (e) {
          _availableIdPs = [];
        }
      } else {
        _availableIdPs = [];
      }

      _isStep2 = true;
      
      // Check for auto-redirect
      if (settings.ssoEnabled && settings.ssoAutoRedirect && _availableIdPs.length == 1) {
        // We notify listeners so UI can see we are in Step 2, 
        // but the actual redirect trigger might need to be handled by UI observing state 
        // or a specific event. 
        // For simplicity, we just stay in Step 2 state, and let UI decide to trigger SSO 
        // if it sees this condition. 
        // OR we could return a specific result.
      }
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Step 2: Login
  Future<void> login(String username, String password, String serverUrl) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(
        username,
        password,
        serverUrl: serverUrl,
      );

      if (result.mfaRequired) {
        _showMfaInput = true;
        _mfaUsername = result.username;
      } else {
        _loginSuccess = true;
      }
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Step 3: MFA
  Future<void> verifyMfa(String code) async {
    if (_mfaUsername == null) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.verifyMfa(_mfaUsername!, code);
      _loginSuccess = true;
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // SSO
  Future<String?> initiateSso(String slug, String serverUrl) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await _ssoService.initiateOAuth(slug, serverUrl: serverUrl);
    } catch (e) {
      _error = e;
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> completeSso(String sessionId) async {
    // Note: Loading state might be handled by UI webview, but good to set it here if we do async work
    _isLoading = true; 
    _error = null; 
    // We don't notifyListeners immediately here if UI is waiting for future completion, 
    // but consistency is good.
    notifyListeners();

    try {
      await _ssoService.exchangeSessionForTokens(sessionId);
      _loginSuccess = true;
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void handleSsoError(Object error) {
    _error = error;
    notifyListeners();
  }
}
