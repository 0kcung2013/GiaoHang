import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

class OrderConfirmationSubmitBar extends StatelessWidget {
  const OrderConfirmationSubmitBar({
    super.key,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: FilledButton.icon(
            onPressed: isSubmitting ? null : onSubmit,
            icon: isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnAccent,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(isSubmitting ? 'Đang tạo đơn...' : 'Xác nhận đặt đơn'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textOnAccent,
              disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.62),
              disabledForegroundColor: AppColors.textOnAccent,
              textStyle: AppTextStyles.labelLarge,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
            ),
          ),
        ),
      ),
    );
  }
}
