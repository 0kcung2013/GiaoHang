import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/risk_queue_scope.dart';

class RiskQueueTabs extends StatelessWidget {
  const RiskQueueTabs({
    required this.value,
    required this.countFor,
    required this.onChanged,
    super.key,
  });

  final RiskQueueScope value;
  final int Function(RiskQueueScope scope) countFor;
  final ValueChanged<RiskQueueScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final scope in RiskQueueScope.values) ...[
            _QueueTab(
              scope: scope,
              selected: scope == value,
              count: countFor(scope),
              onTap: () => onChanged(scope),
            ),
            if (scope != RiskQueueScope.values.last)
              const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _QueueTab extends StatelessWidget {
  const _QueueTab({
    required this.scope,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final RiskQueueScope scope;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${_label(scope)}, $count báo cáo',
      child: Material(
        color: selected ? AppColors.primary : AppColors.bgCard,
        borderRadius: AppRadius.full,
        child: InkWell(
          key: ValueKey('risk-queue-${scope.name}'),
          onTap: onTap,
          borderRadius: AppRadius.full,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.full,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _icon(scope),
                  size: 18,
                  color: selected
                      ? AppColors.textOnDark
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _label(scope),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: selected
                        ? AppColors.textOnDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.textOnDark.withValues(alpha: 0.14)
                        : AppColors.bgLight,
                    borderRadius: AppRadius.full,
                  ),
                  child: Text(
                    '$count',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: selected
                          ? AppColors.textOnDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _label(RiskQueueScope scope) => switch (scope) {
  RiskQueueScope.newReports => 'Mới',
  RiskQueueScope.overdue => 'Quá SLA',
  RiskQueueScope.mine => 'Của tôi',
  RiskQueueScope.waitingAdmin => 'Cần Admin',
  RiskQueueScope.closed => 'Đã đóng',
  RiskQueueScope.all => 'Tất cả',
};

IconData _icon(RiskQueueScope scope) => switch (scope) {
  RiskQueueScope.newReports => Icons.fiber_new_rounded,
  RiskQueueScope.overdue => Icons.timer_off_outlined,
  RiskQueueScope.mine => Icons.person_rounded,
  RiskQueueScope.waitingAdmin => Icons.admin_panel_settings_outlined,
  RiskQueueScope.closed => Icons.task_alt_rounded,
  RiskQueueScope.all => Icons.list_alt_rounded,
};
