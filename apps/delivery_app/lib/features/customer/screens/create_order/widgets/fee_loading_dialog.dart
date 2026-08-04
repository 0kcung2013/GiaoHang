import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

class FeeLoadingDialog extends StatelessWidget {
  const FeeLoadingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl2),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.md,
              ),
              child: const Icon(Icons.route_rounded, color: AppColors.accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Đang tính quãng đường',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Phí giao hàng sẽ được hiển thị trước khi bạn xác nhận.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ClipRRect(
              borderRadius: AppRadius.full,
              child: const LinearProgressIndicator(
                minHeight: 5,
                color: AppColors.accent,
                backgroundColor: AppColors.accentLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
