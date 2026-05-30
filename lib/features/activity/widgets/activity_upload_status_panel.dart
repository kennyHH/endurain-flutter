import 'package:endurain/core/utils/error_localizations.dart';
import 'package:endurain/features/activity/models/activity_upload_state.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ActivityUploadStatusPanel extends StatelessWidget {
  const ActivityUploadStatusPanel({
    super.key,
    required this.status,
    required this.error,
    required this.onRetry,
    required this.onDiscard,
  });

  final ActivityUploadStatus status;
  final Object? error;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _statusText(l10n),
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (status == ActivityUploadStatus.failed && error != null) ...[
          const SizedBox(height: 4),
          Text(
            localizedErrorMessage(error!, l10n),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (status == ActivityUploadStatus.failed ||
            status == ActivityUploadStatus.uploaded) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == ActivityUploadStatus.failed)
                AdaptiveButton(
                  label: l10n.activityRetryUpload,
                  onPressed: onRetry,
                  icon: const AdaptiveIcon(
                    materialIcon: Icons.refresh,
                    cupertinoIcon: CupertinoIcons.refresh,
                    size: 20,
                  ),
                ),
              AdaptiveButton(
                label: l10n.activityDiscard,
                onPressed: onDiscard,
                destructive: true,
                variant: AdaptiveButtonVariant.secondary,
                icon: const AdaptiveIcon(
                  materialIcon: Icons.delete_outline,
                  cupertinoIcon: CupertinoIcons.delete,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _statusText(AppLocalizations l10n) {
    return switch (status) {
      ActivityUploadStatus.idle => l10n.activityUploadReady,
      ActivityUploadStatus.uploading => l10n.activityUploading,
      ActivityUploadStatus.uploaded => l10n.activityUploaded,
      ActivityUploadStatus.failed => l10n.activityUploadFailed,
    };
  }
}
