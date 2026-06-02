import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';

class CreateOrderHeader extends StatelessWidget {
  const CreateOrderHeader({super.key});

  @override
  Widget build(BuildContext context) {
    const steps = ['Địa chỉ', 'Người nhận', 'Dịch vụ', 'Xác nhận'];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: AppColors.textOnAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tạo đơn giao hàng',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingLarge.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Nhập thông tin lấy hàng và giao hàng',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textOnDark.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: _StepPill(index: i + 1, label: steps[i]),
                ),
                if (i != steps.length - 1)
                  Container(
                    width: AppSpacing.sm,
                    height: 1,
                    color: AppColors.textOnDark.withValues(alpha: 0.22),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.index, required this.label});

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: index == 1 ? AppColors.accent : Colors.transparent,
            borderRadius: AppRadius.full,
            border: Border.all(
              color: index == 1
                  ? AppColors.accent
                  : AppColors.textOnDark.withValues(alpha: 0.32),
            ),
          ),
          child: Center(
            child: Text(
              '$index',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textOnAccent,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textOnDark.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}
