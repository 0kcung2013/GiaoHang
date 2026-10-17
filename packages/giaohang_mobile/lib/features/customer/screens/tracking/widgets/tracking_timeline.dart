part of '../tracking_screen.dart';

class _TrackingTimeline extends ConsumerWidget {
  const _TrackingTimeline({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(orderStatusLogsProvider(order.id));
    final currentLogs = logsAsync.valueOrNull;
    final content = currentLogs != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TimelineStepList(steps: _timelineSteps(order, currentLogs)),
              if (logsAsync.isRefreshing || logsAsync.isReloading) ...[
                const SizedBox(height: AppSpacing.md),
                const _InlineLoading(label: 'Đang cập nhật trạng thái...'),
              ],
            ],
          )
        : logsAsync.when(
            loading: () =>
                const _InlineLoading(label: 'Đang tải trạng thái...'),
            error: (_, _) =>
                _TimelineStepList(steps: _fallbackTimelineSteps(order)),
            data: (logs) =>
                _TimelineStepList(steps: _timelineSteps(order, logs)),
          );

    return _TrackingExpandableCard(
      title: 'Hành trình đơn hàng',
      subtitle: 'Xem các mốc xử lý và thời gian cập nhật',
      icon: Icons.route_rounded,
      initiallyExpanded: true,
      child: content,
    );
  }
}

class _TimelineStepList extends StatelessWidget {
  const _TimelineStepList({required this.steps});

  final List<_TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: AppSpacing.xl2,
                child: Column(
                  children: [
                    Container(
                      width: AppSpacing.lg,
                      height: AppSpacing.lg,
                      margin: const EdgeInsets.only(top: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: step.done ? AppColors.accent : AppColors.bgCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: step.done
                              ? AppColors.accent
                              : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: step.done
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.textOnAccent,
                              size: AppSpacing.sm,
                            )
                          : null,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          color: step.done
                              ? AppColors.accent.withValues(alpha: 0.35)
                              : AppColors.border,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: step.done
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        step.time,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: step.done
                              ? AppColors.accent
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        step.description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
