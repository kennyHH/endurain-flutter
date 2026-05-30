import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/core/utils/platform_utils.dart';

class AdaptiveListSection extends StatelessWidget {
  const AdaptiveListSection({super.key, this.header, required this.children});

  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isApplePlatform) {
      return CupertinoListSection.insetGrouped(
        header: header == null ? null : Text(header!),
        margin: EdgeInsets.zero,
        children: children,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UIConstants.paddingStandard,
                UIConstants.paddingMedium,
                UIConstants.paddingStandard,
                UIConstants.paddingSmall,
              ),
              child: Text(
                header!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}
