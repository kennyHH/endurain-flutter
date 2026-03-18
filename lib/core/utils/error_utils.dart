import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:endurain/core/utils/platform_utils.dart';

class ErrorUtils {
  static Future<void> showRetryDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onRetry,
    String? retryLabel,
    String? cancelLabel,
  }) async {
    final retryText = retryLabel ?? 'Retry';
    final cancelText = cancelLabel ?? 'Cancel';

    if (PlatformUtils.isApplePlatform) {
      return showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text(retryText),
            ),
          ],
        ),
      );
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        icon: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          size: 48,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(cancelText),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry();
            },
            icon: const Icon(Icons.refresh),
            label: Text(retryText),
          ),
        ],
      ),
    );
  }
}
