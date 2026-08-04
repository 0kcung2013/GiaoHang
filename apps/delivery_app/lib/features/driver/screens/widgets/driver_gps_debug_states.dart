import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

class DriverGpsLoadingState extends StatelessWidget {
  const DriverGpsLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Đang lấy GPS hiện tại...', style: AppTextStyles.headingSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Quá trình này có thể mất vài giây.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ...List.generate(
          3,
          (index) => Container(
            height: index == 0 ? 224 : 78,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }
}

class DriverGpsErrorState extends StatelessWidget {
  const DriverGpsErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.07),
        borderRadius: AppRadius.xl,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.location_off_rounded,
            color: AppColors.error,
            size: 40,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Không thể xác định vị trí',
            textAlign: TextAlign.center,
            style: AppTextStyles.headingSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
