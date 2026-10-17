import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

class CustomerWalletLoadingCard extends StatelessWidget {
  const CustomerWalletLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đang tải Ví khách hàng',
      child: Container(
        height: 264,
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl2,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _Skeleton(width: 132, height: 18),
            SizedBox(height: AppSpacing.xl3),
            _Skeleton(width: 104, height: 14),
            SizedBox(height: AppSpacing.sm),
            _Skeleton(width: 216, height: 34),
            Spacer(),
            _Skeleton(width: double.infinity, height: 50),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.border,
        borderRadius: AppRadius.sm,
      ),
    );
  }
}

class CustomerWalletErrorCard extends StatelessWidget {
  const CustomerWalletErrorCard({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl2,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: AppColors.error,
            size: 32,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Chưa tải được số dư',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
          ),
        ],
      ),
    );
  }
}
