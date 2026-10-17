import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../core/utils/money_formatter.dart';
import '../models/driver_goods_deposit.dart';

abstract final class DriverGoodsDepositText {
  static const paid = 'Đã thanh toán';
  static const collect = 'Thu người nhận';
  static const deposit = 'Tiền làm tin';
  static const required = 'Chưa giữ tiền';
  static const held = 'Đang giữ tiền làm tin';
  static const holdConfirmed = 'ĐÃ GIỮ TIỀN LÀM TIN';
  static const pending = 'Chờ xác nhận hoàn tiền';
  static const refunded = 'Đã hoàn tiền cọc giữ hàng';
  static const verify = 'Cần kiểm tra ví';
  static const pickupHint = 'Giữ từ ví khi xác nhận lấy hàng.';
  static const heldHint = 'Hoàn vào ví khi giao thành công.';
  static const refundedHint = 'Đã cộng lại vào số dư khả dụng.';
  static const pendingHint = 'Đang kiểm tra giao dịch hoàn vào ví.';
  static const verifyHint = 'Liên hệ CSKH để đối soát tiền làm tin.';
  static const earning = 'Thu nhập giao hàng';
  static const loading = 'Đang cập nhật tiền làm tin';
  static const unverified = 'Chưa xác minh tiền làm tin';
  static const retry = 'Thử lại';
  static const pickupUnverified =
      'Đã nhận hàng. Chưa xác minh được tiền làm tin.';
  static String topUp(int amount) => 'Nạp thêm ${formatVnd(amount)}';
}

/// Renders deposit status from confirmed wallet receipts.
class DriverGoodsDepositPanel extends StatelessWidget {
  const DriverGoodsDepositPanel({
    super.key,
    required this.deposit,
    required this.receiverCollectionAmount,
    required this.driverNetEarning,
    this.availableBalance,
  });

  final DriverGoodsDeposit deposit;
  final int receiverCollectionAmount;
  final int driverNetEarning;
  final int? availableBalance;

  @override
  Widget build(BuildContext context) {
    final refunded = deposit.status == DriverGoodsDepositStatus.refunded;
    final (label, hint, icon) = switch (deposit.status) {
      DriverGoodsDepositStatus.required => (
        DriverGoodsDepositText.required,
        DriverGoodsDepositText.pickupHint,
        Icons.lock_outline_rounded,
      ),
      DriverGoodsDepositStatus.held => (
        DriverGoodsDepositText.held,
        DriverGoodsDepositText.heldHint,
        Icons.lock_rounded,
      ),
      DriverGoodsDepositStatus.refundPending => (
        DriverGoodsDepositText.pending,
        DriverGoodsDepositText.pendingHint,
        Icons.sync_rounded,
      ),
      DriverGoodsDepositStatus.refunded => (
        DriverGoodsDepositText.refunded,
        DriverGoodsDepositText.refundedHint,
        Icons.check_circle_rounded,
      ),
      DriverGoodsDepositStatus.verificationRequired => (
        DriverGoodsDepositText.verify,
        DriverGoodsDepositText.verifyHint,
        Icons.info_outline_rounded,
      ),
    };
    final missing =
        deposit.status == DriverGoodsDepositStatus.required &&
            availableBalance != null
        ? (deposit.amount - availableBalance!).clamp(0, deposit.amount)
        : 0;
    // Navy text keeps small status copy readable on orange/green tints.
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    DriverGoodsDepositText.paid,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _MoneyRow(
              label: DriverGoodsDepositText.collect,
              value: formatVnd(receiverCollectionAmount),
            ),
            const Divider(height: AppSpacing.xl2, color: AppColors.border),
            _MoneyRow(
              label: DriverGoodsDepositText.deposit,
              value: '${refunded ? '+' : ''}${formatVnd(deposit.amount)}',
              prominent: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: refunded
                    ? AppColors.success.withValues(alpha: 0.10)
                    : AppColors.accentLight,
                borderRadius: AppRadius.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          hint,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _MoneyRow(
              label: DriverGoodsDepositText.earning,
              value: formatVnd(driverNetEarning),
            ),
            if (missing > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                DriverGoodsDepositText.topUp(missing),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.xs,
    children: [
      Text(label, style: AppTextStyles.bodyMedium),
      Text(
        value,
        style:
            (prominent
                    ? AppTextStyles.headingLarge
                    : AppTextStyles.headingSmall)
                .copyWith(color: AppColors.primary),
      ),
    ],
  );
}
