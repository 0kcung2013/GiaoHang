import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';

class CreateOrderHeader extends StatelessWidget {
  const CreateOrderHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF1A3A5C)],
        ),
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.elevated,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: AppRadius.md,
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: AppColors.accent,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tạo đơn giao hàng mới',
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Điền thông tin bên dưới để tiếp tục',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.65),
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
