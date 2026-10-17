import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/customer_wallet.dart';
import '../../../../../core/utils/money_formatter.dart';
import 'customer_wallet_history_sheet.dart';
import 'customer_wallet_withdraw_sheet.dart';

class CustomerWalletSurface extends StatelessWidget {
  const CustomerWalletSurface({
    super.key,
    required this.summary,
    required this.transactions,
  });

  final CustomerWalletSummary summary;
  final List<CustomerWalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Ví khách hàng, số dư khả dụng '
          '${formatVnd(summary.availableBalance)}',
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl2,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.16)),
          boxShadow: AppShadow.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _BalancePanel(summary: summary),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _LatestTransaction(transaction: transactions.firstOrNull),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _WalletActionButton(
                          icon: Icons.receipt_long_rounded,
                          label: 'Lịch sử',
                          onPressed: () => showCustomerWalletHistorySheet(
                            context,
                            summary: summary,
                            transactions: transactions,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _WalletActionButton(
                          icon: Icons.north_east_rounded,
                          label: 'Rút tiền',
                          filled: true,
                          onPressed: summary.availableBalance > 0
                              ? () => _openWithdrawSheet(context)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWithdrawSheet(BuildContext context) async {
    final amount = await showCustomerWalletWithdrawSheet(
      context,
      availableBalance: summary.availableBalance,
    );
    if (amount == null || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Đã mô phỏng yêu cầu rút ${formatVnd(amount)}.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      );
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({required this.summary});

  final CustomerWalletSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('customer_wallet_balance_panel'),
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.bgCard, AppColors.accentLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -48,
            child: _DecorativeCircle(
              size: 132,
              color: AppColors.accent.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            right: 42,
            bottom: -40,
            child: _DecorativeCircle(
              size: 92,
              color: AppColors.accent.withValues(alpha: 0.14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: AppRadius.md,
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppColors.accent,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'VÍ GIAO HÀNG',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.14),
                        borderRadius: AppRadius.full,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shield_rounded,
                            size: 13,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'AN TOÀN',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Số dư khả dụng',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatVnd(summary.availableBalance),
                    style: AppTextStyles.displayLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Icon(
                      Icons.south_west_rounded,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Đã nhận ${formatVnd(summary.totalReceived)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'COD quyết toán',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _LatestTransaction extends StatelessWidget {
  const _LatestTransaction({required this.transaction});

  final CustomerWalletTransaction? transaction;

  @override
  Widget build(BuildContext context) {
    final item = transaction;
    final delta = item?.availableDelta ?? 0;
    final positive = delta >= 0;
    final color = item == null
        ? AppColors.textMuted
        : positive
        ? AppColors.success
        : AppColors.error;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.md,
          ),
          child: Icon(
            item == null
                ? Icons.receipt_long_outlined
                : positive
                ? Icons.south_west_rounded
                : Icons.north_east_rounded,
            color: color,
            size: 19,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item?.label ?? 'Chưa có giao dịch',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item == null ? 'Lịch sử sẽ xuất hiện tại đây' : 'Gần nhất',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (item != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${positive ? '+' : '-'}${formatVnd(delta.abs())}',
            style: AppTextStyles.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: AppRadius.full);
    return SizedBox(
      height: 50,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.border,
                foregroundColor: AppColors.textOnAccent,
                disabledForegroundColor: AppColors.textMuted,
                textStyle: AppTextStyles.labelMedium,
                shape: shape,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                textStyle: AppTextStyles.labelMedium,
                shape: shape,
              ),
            ),
    );
  }
}
