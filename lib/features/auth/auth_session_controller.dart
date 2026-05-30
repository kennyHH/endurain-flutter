import 'package:flutter/foundation.dart';
import 'package:endurain/core/services/auth_service.dart';

class AuthSessionController extends ChangeNotifier {
  AuthSessionController({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  bool isLoading = true;
  bool isAuthenticated = false;

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();

    isAuthenticated = await _authService.isAuthenticated();
    isLoading = false;
    notifyListeners();
  }

  void markAuthenticated() {
    isAuthenticated = true;
    isLoading = false;
    notifyListeners();
  }

  void markUnauthenticated() {
    isAuthenticated = false;
    isLoading = false;
    notifyListeners();
  }
}
