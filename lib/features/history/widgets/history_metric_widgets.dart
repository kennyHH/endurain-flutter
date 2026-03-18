import 'package:flutter/material.dart';

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.width,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final double? width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? 164,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 8 : 9,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: compact ? 15 : 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: compact ? 6 : 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: compact ? 10.5 : null,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 14.5 : 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdaptiveMetricGrid extends StatelessWidget {
  const AdaptiveMetricGrid({super.key, required this.children, required this.compact});

  final List<MetricTile> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = compact ? 8.0 : 10.0;
        final minWidth = compact ? 136.0 : 156.0;
        final maxColumns = constraints.maxWidth >= 640 ? 3 : 2;
        final columns =
            ((constraints.maxWidth + spacing) / (minWidth + spacing))
                .floor()
                .clamp(1, maxColumns);
        final tileWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map(
                (tile) => MetricTile(
                  icon: tile.icon,
                  label: tile.label,
                  value: tile.value,
                  compact: tile.compact,
                  width: tileWidth,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class CompactMetric extends StatelessWidget {
  const CompactMetric({
    super.key,
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: compact ? 9 : null,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: compact ? 0 : 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 13 : null,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );

    return container;
  }
}
