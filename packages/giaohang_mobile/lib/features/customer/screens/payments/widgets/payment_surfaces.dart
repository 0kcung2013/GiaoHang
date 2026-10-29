import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show formatVnd;

import '../models/customer_payment.dart';
import '../models/customer_payment_statistics.dart';
import '../payment_strings.dart';

class PaymentSurface extends StatelessWidget {
  const PaymentSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.xl,
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class PaymentSummary extends StatelessWidget {
  const PaymentSummary({super.key, required this.statistics});
  final CustomerPaymentStatistics statistics;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl2),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadius.xl2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              PaymentStrings.successful,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textOnDark,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              formatVnd(statistics.total).replaceAll('.', '.\u200b'),
              key: const Key('payment-total'),
              semanticsLabel: formatVnd(statistics.total),
              style: AppTextStyles.displayLarge.copyWith(
                color: AppColors.textOnDark,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.textOnDark,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    PaymentStrings.successfulCount(statistics.completed.length),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      PaymentSurface(
        child: Column(
          children: [
            for (final state in [
              CustomerPaymentState.refunded,
              CustomerPaymentState.reserved,
              CustomerPaymentState.refundPending,
              CustomerPaymentState.pending,
            ])
              if (state == CustomerPaymentState.refunded ||
                  statistics.amount(state) > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final label = Text(
                        state.label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      );
                      final value = Text(
                        formatVnd(statistics.amount(state)),
                        style: AppTextStyles.labelLarge,
                      );
                      final stacked =
                          constraints.maxWidth < 290 ||
                          MediaQuery.textScalerOf(context).scale(14) > 20;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            state == CustomerPaymentState.refunded
                                ? Icons.undo_rounded
                                : Icons.schedule_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: stacked
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      label,
                                      const SizedBox(height: AppSpacing.xs),
                                      value,
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: label),
                                      const SizedBox(width: AppSpacing.md),
                                      value,
                                    ],
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    ],
  );
}

class PaymentMethodBreakdown extends StatelessWidget {
  const PaymentMethodBreakdown({super.key, required this.statistics});
  final CustomerPaymentStatistics statistics;

  @override
  Widget build(BuildContext context) => PaymentSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(PaymentStrings.byMethod, style: AppTextStyles.headingSmall),
        for (final method in CustomerPaymentMethod.values) ...[
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(method.label, style: AppTextStyles.bodyMedium),
              Text(
                formatVnd(statistics.methodTotal(method)),
                style: AppTextStyles.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: statistics.total == 0
                ? 0
                : statistics.methodTotal(method) / statistics.total,
            color: method == CustomerPaymentMethod.wallet
                ? AppColors.primary
                : AppColors.accent,
            backgroundColor: AppColors.border,
            borderRadius: AppRadius.full,
            minHeight: AppSpacing.sm,
            semanticsLabel: method.label,
            semanticsValue: formatVnd(statistics.methodTotal(method)),
          ),
        ],
      ],
    ),
  );
}

class PaymentMessage extends StatelessWidget {
  const PaymentMessage({super.key, this.failed = false, this.onRetry});
  final bool failed;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => PaymentSurface(
    child: Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        Icon(
          failed ? Icons.cloud_off_rounded : Icons.receipt_long_rounded,
          size: 40,
          color: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          failed ? PaymentStrings.loadError : PaymentStrings.empty,
          textAlign: TextAlign.center,
          style: AppTextStyles.headingSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          failed ? PaymentStrings.loadHint : PaymentStrings.emptyHint,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(PaymentStrings.retry),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    ),
  );
}
