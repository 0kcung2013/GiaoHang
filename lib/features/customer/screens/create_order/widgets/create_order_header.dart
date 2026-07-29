import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';

class CreateOrderHeader extends StatelessWidget {
  const CreateOrderHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: AppRadius.sm,
            ),
            child: Text(
              'GIAO HÀNG THEO YÊU CẦU',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.65,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Gửi một kiện hàng',
            style: AppTextStyles.displayMedium.copyWith(
              color: AppColors.textPrimary,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chọn lộ trình trước, sau đó thêm thông tin người nhận và kiện hàng.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
