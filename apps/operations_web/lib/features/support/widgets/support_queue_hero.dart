import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class SupportQueueHero extends StatelessWidget {
  const SupportQueueHero({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.metrics,
    this.action,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<SupportQueueMetric> metrics;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        boxShadow: AppShadow.card,
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: ColoredBox(
              color: AppColors.accent,
              child: SizedBox(width: 5),
            ),
          ),
          Positioned(
            right: -40,
            top: -54,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentLight.withValues(alpha: 0.72),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final heading = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: AppRadius.lg,
                            boxShadow: AppShadow.accentGlow,
                          ),
                          child: Icon(icon, color: AppColors.textOnAccent),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AppTextStyles.headingLarge),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                subtitle,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                    if (action == null) return heading;
                    if (constraints.maxWidth < 620) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading,
                          const SizedBox(height: AppSpacing.lg),
                          action!,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: heading),
                        const SizedBox(width: AppSpacing.xl),
                        action!,
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl2),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth < 720
                        ? (constraints.maxWidth - AppSpacing.sm) / 2
                        : (constraints.maxWidth -
                                  (metrics.length - 1) * AppSpacing.sm) /
                              metrics.length;
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: metrics
                          .map(
                            (metric) => SizedBox(
                              width: width,
                              child: _MetricTile(metric: metric),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SupportQueueMetric {
  const SupportQueueMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});
  final SupportQueueMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgWarm,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.1),
              borderRadius: AppRadius.sm,
            ),
            child: Icon(metric.icon, color: metric.color, size: 19),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${metric.value}', style: AppTextStyles.headingSmall),
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
