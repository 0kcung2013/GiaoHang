import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';

const createOrderHeaderKey = Key('create-order-header');

class CreateOrderHeader extends StatelessWidget {
  const CreateOrderHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Container(
        key: createOrderHeaderKey,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl2,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
          boxShadow: AppShadow.card,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: -36,
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: AppRadius.lg,
                        boxShadow: AppShadow.accentGlow,
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: AppColors.textOnAccent,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TẠO CHUYẾN GIAO',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Gửi hàng thật dễ',
                            style: AppTextStyles.headingLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Điền thông tin theo từng bước. Bạn sẽ được xem phí và kiểm tra lại trước khi đặt đơn.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const _ProgressPart(active: true),
                    const SizedBox(width: AppSpacing.sm),
                    const _ProgressPart(active: false),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Bước 1/2 · Nhập thông tin',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressPart extends StatelessWidget {
  const _ProgressPart({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 5,
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.border,
          borderRadius: AppRadius.full,
        ),
      ),
    );
  }
}
