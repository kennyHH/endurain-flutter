import 'package:flutter/material.dart';
import 'package:endurain/core/error_handling/app_error.dart';
import 'package:endurain/core/error_handling/error_overlay.dart';
import 'package:injectable/injectable.dart';

@singleton
class ErrorHandlerService {
  void showError({
    required BuildContext context,
    required dynamic error,
    VoidCallback? onRetry,
    VoidCallback? onClose,
    bool isCritical = true,
  }) {
    final appError = _convertError(error);
    _logError(appError);

    if (isCritical) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ErrorOverlay(
          error: appError,
          onRetry: onRetry != null
              ? () {
                  Navigator.of(context).pop();
                  onRetry();
                }
              : null,
          onClose: () {
            Navigator.of(context).pop();
            onClose?.call();
          },
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appError.message),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: onRetry != null
              ? SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
              : null,
        ),
      );
    }
  }

  AppError _convertError(dynamic error) {
    if (error is AppError) return error;

    final message = error.toString();
    if (message.contains('SocketException') ||
        message.contains('Connection refused') ||
        message.contains('Network is unreachable') ||
        message.contains('ClientException')) {
      return NetworkError(
          message: 'Please check your internet connection.',
          originalError: error);
    }

    if (message.contains('401') || message.contains('Unauthorized')) {
      return AuthenticationError(
          message: 'Your session has expired. Please log in again.',
          originalError: error);
    }
    
    if (message.contains('Location services are disabled')) {
      return GpsUnavailableError(
        message: 'Location services are disabled. Please enable GPS.',
        originalError: error,
      );
    }

    // Default fallback
    return UnknownError(
        message: 'An unexpected error occurred.', originalError: error);
  }

  void _logError(AppError error) {
    debugPrint('[ErrorHandler] ${error.type}: ${error.message}');
    if (error.originalError != null) {
      debugPrint('[ErrorHandler] Original: ${error.originalError}');
    }
    if (error.stackTrace != null) {
      debugPrint('[ErrorHandler] StackTrace: ${error.stackTrace}');
    }
  }
}
