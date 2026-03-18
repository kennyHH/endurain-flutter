enum AppErrorType {
  network,
  authentication,
  upload,
  gpsUnavailable,
  unknown,
}

abstract class AppError {
  AppError({
    required this.type,
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  final AppErrorType type;
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;
}

class NetworkError extends AppError {
  NetworkError({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(type: AppErrorType.network);
}

class AuthenticationError extends AppError {
  AuthenticationError({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(type: AppErrorType.authentication);
}

class UploadError extends AppError {
  UploadError({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(type: AppErrorType.upload);
}

class GpsUnavailableError extends AppError {
  GpsUnavailableError({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(type: AppErrorType.gpsUnavailable);
}

class UnknownError extends AppError {
  UnknownError({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(type: AppErrorType.unknown);
}
