import 'package:endurain/core/constants/activity_type_catalog.dart';
import 'package:endurain/core/constants/tracking_ui_tokens.dart';
import 'package:endurain/core/theme/endurain_design_system.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

Future<int?> showActivityTypePickerSheet({
  required BuildContext context,
  required int selectedTypeId,
  required String Function(ActivityTypeCatalogItem) labelBuilder,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.56,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return _ActivityTypePickerSheet(
            selectedTypeId: selectedTypeId,
            labelBuilder: labelBuilder,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _ActivityTypePickerSheet extends StatelessWidget {
  const _ActivityTypePickerSheet({
    required this.selectedTypeId,
    required this.labelBuilder,
    required this.scrollController,
  });

  final int selectedTypeId;
  final String Function(ActivityTypeCatalogItem) labelBuilder;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            EndurainSpacing.md,
            EndurainSpacing.sm,
            EndurainSpacing.md,
            EndurainSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: EndurainSpacing.sm),
              Text(
                l10n.activityTypeLabel,
                style: EndurainTypography.headline(colorScheme),
              ),
              const SizedBox(height: EndurainSpacing.sm),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: ActivityTypeCatalog.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: EndurainSpacing.xs),
                  itemBuilder: (context, index) {
                    final item = ActivityTypeCatalog.items[index];
                    final isSelected = item.id == selectedTypeId;
                    final baseColor = isSelected
                        ? EndurainColors.darkPrimary.withValues(alpha: 0.14)
                        : colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.28,
                          );
                    final iconColor = isSelected
                        ? EndurainColors.darkPrimary
                        : colorScheme.onSurfaceVariant;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: Key('activity-type-option-${item.id}'),
                        borderRadius: BorderRadius.circular(TrackingRadius.md),
                        onTap: () => Navigator.of(context).pop(item.id),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(
                              TrackingRadius.md,
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? EndurainColors.darkPrimary
                                  : colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: EndurainSpacing.sm,
                              vertical: EndurainSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Icon(item.icon, size: 20, color: iconColor),
                                const SizedBox(width: EndurainSpacing.sm),
                                Expanded(
                                  child: Text(
                                    labelBuilder(item),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        EndurainTypography.metricLabel(
                                          colorScheme,
                                        ).copyWith(
                                          color: colorScheme.onSurface,
                                          fontSize: 14,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: EndurainSpacing.xs),
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? EndurainColors.darkPrimary
                                      : colorScheme.outline,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
