import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/money_formatter.dart';

class DriverOrderFinancePanel extends StatelessWidget {
  const DriverOrderFinancePanel({
    super.key,
    required this.order,
    this.availableBalance,
  });

  final OrderModel order;
  final int? availableBalance;

  int get requiredBalance => order.driverAdvanceAmount;
  bool get collectsCash => order.receiverCollectionAmount > 0;

  int get missingBalance {
    if (requiredBalance <= 0 || availableBalance == null) {
      return 0;
    }
    return (requiredBalance - availableBalance!).clamp(0, requiredBalance);
  }

  @override
  Widget build(BuildContext context) {
    return collectsCash ? _buildCod() : _buildPrepaid();
  }

  Widget _buildCod() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            requiredBalance > 0 ? 'COD · CẦN ỨNG' : 'THU PHÍ KHI GIAO',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatVnd(
              requiredBalance > 0
                  ? order.driverAdvanceAmount
                  : order.receiverCollectionAmount,
            ),
            style: AppTextStyles.headingLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _AmountCell(
                  label: 'Thu người nhận',
                  value: formatVnd(order.receiverCollectionAmount),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _AmountCell(
                  label: 'Thực nhận',
                  value: formatVnd(order.driverNetEarning),
                  valueColor: AppColors.success,
                ),
              ),
            ],
          ),
          if (missingBalance > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 16,
                  color: AppColors.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Nạp thêm ${formatVnd(missingBalance)}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrepaid() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppColors.success,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PHÍ ĐÃ THANH TOÁN',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  order.codCollectionAmount > 0
                      ? 'Thu COD ${formatVnd(order.codCollectionAmount)}'
                      : '0đ cần thu',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Text(
              'Thực nhận ${formatVnd(order.driverNetEarning)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountCell extends StatelessWidget {
  const _AmountCell({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
