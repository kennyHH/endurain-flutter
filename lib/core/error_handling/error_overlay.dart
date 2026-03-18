import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:endurain/core/error_handling/app_error.dart';
import 'package:endurain/core/utils/platform_utils.dart';

class ErrorOverlay extends StatelessWidget {
  const ErrorOverlay({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onClose,
  });

  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isApplePlatform) {
      return CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getErrorIcon(error.type),
              color: CupertinoColors.systemRed,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(_getErrorTitle(error.type)),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(error.message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: onClose,
            isDestructiveAction: true,
            child: const Text('Close'),
          ),
          if (onRetry != null)
            CupertinoDialogAction(
              onPressed: onRetry,
              isDefaultAction: true,
              child: const Text('Retry'),
            ),
        ],
      );
    }

    return AlertDialog(
      icon: Icon(
        _getErrorIcon(error.type),
        color: Theme.of(context).colorScheme.error,
        size: 32,
      ),
      title: Text(
        _getErrorTitle(error.type),
        textAlign: TextAlign.center,
      ),
      content: Text(
        error.message,
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: onClose,
          child: const Text('Close'),
        ),
        if (onRetry != null)
          FilledButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
      ],
    );
  }

  IconData _getErrorIcon(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
        return PlatformUtils.isApplePlatform
            ? CupertinoIcons.wifi_slash
            : Icons.wifi_off_rounded;
      case AppErrorType.authentication:
        return PlatformUtils.isApplePlatform
            ? CupertinoIcons.lock_shield
            : Icons.lock_person_rounded;
      case AppErrorType.upload:
        return PlatformUtils.isApplePlatform
            ? CupertinoIcons.cloud_upload
            : Icons.cloud_off_rounded;
      case AppErrorType.gpsUnavailable:
        return PlatformUtils.isApplePlatform
            ? CupertinoIcons.location_slash
            : Icons.gps_off_rounded;
      case AppErrorType.unknown:
        return PlatformUtils.isApplePlatform
            ? CupertinoIcons.exclamationmark_triangle
            : Icons.error_outline_rounded;
    }
  }

  String _getErrorTitle(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
        return 'Network Error';
      case AppErrorType.authentication:
        return 'Authentication Failed';
      case AppErrorType.upload:
        return 'Upload Failed';
      case AppErrorType.gpsUnavailable:
        return 'GPS Unavailable';
      case AppErrorType.unknown:
        return 'Error';
    }
  }
}
