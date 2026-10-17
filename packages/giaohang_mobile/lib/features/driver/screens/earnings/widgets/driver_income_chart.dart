import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../utils/driver_income_breakdown.dart';

class DriverIncomeChart extends StatelessWidget {
  const DriverIncomeChart({
    super.key,
    required this.buckets,
    required this.totalIncome,
  });

  final List<DriverIncomeBucket> buckets;
  final int totalIncome;

  @override
  Widget build(BuildContext context) {
    final maxAmount = buckets.fold<int>(
      0,
      (maximum, bucket) => math.max(maximum, bucket.amount),
    );

    return Container(
      key: const ValueKey('driver-income-chart'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thu nhập kỳ này',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatVnd(totalIncome),
            style: AppTextStyles.displayMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final bucket in buckets) ...[
            _IncomeBar(bucket: bucket, maxAmount: maxAmount),
            if (bucket != buckets.last) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _IncomeBar extends StatelessWidget {
  const _IncomeBar({required this.bucket, required this.maxAmount});

  final DriverIncomeBucket bucket;
  final int maxAmount;

  @override
  Widget build(BuildContext context) {
    final fraction = maxAmount == 0 ? 0.0 : bucket.amount / maxAmount;
    return Semantics(
      label: '${bucket.label}, ${formatVnd(bucket.amount)}',
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              bucket.label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: AppRadius.sm,
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = bucket.amount == 0
                      ? 3.0
                      : math.max(8.0, constraints.maxWidth * fraction);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: AppDuration.normal,
                      curve: AppCurve.decelerate,
                      width: width,
                      decoration: BoxDecoration(
                        color: bucket.amount == 0
                            ? AppColors.border
                            : AppColors.accent,
                        borderRadius: AppRadius.sm,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 84,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatVnd(bucket.amount),
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
