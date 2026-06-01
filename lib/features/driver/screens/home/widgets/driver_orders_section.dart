import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import 'driver_order_card.dart';
import 'driver_state_widgets.dart';

/// Section card containing a titled list of [DriverOrderCard]s or an empty state.
class DriverOrdersSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<OrderModel> orders;
  final String emptyTitle;
  final String emptyMessage;

  /// When set, order cards show the "Accept" button.
  final String? acceptDriverId;

  const DriverOrdersSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.orders,
    required this.emptyTitle,
    required this.emptyMessage,
    this.acceptDriverId,
  });

  @override
  Widget build(BuildContext context) {
    return DriverSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (orders.isEmpty)
              _DriverEmptyCard(title: emptyTitle, message: emptyMessage)
            else
              ...orders.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: DriverOrderCard(
                    order: order,
                    acceptDriverId: acceptDriverId,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty card ────────────────────────────────────────────────────────────

class _DriverEmptyCard extends StatelessWidget {
  final String title;
  final String message;

  const _DriverEmptyCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.info,
              size: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
