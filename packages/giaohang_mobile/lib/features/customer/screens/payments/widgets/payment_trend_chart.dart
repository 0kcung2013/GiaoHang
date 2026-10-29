import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show formatVnd;

import '../models/customer_payment.dart';
import '../models/customer_payment_statistics.dart';
import '../payment_strings.dart';
import 'payment_surfaces.dart';

class PaymentTrendChart extends StatefulWidget {
  const PaymentTrendChart({super.key, required this.buckets});
  final List<CustomerPaymentBucket> buckets;
  @override
  State<PaymentTrendChart> createState() => _PaymentTrendChartState();
}

class _PaymentTrendChartState extends State<PaymentTrendChart> {
  int? _selected;
  @override
  void didUpdateWidget(covariant PaymentTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final maximum = widget.buckets.fold(
      0,
      (maximum, bucket) => math.max(maximum, bucket.amount),
    );
    return PaymentSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(PaymentStrings.trend, style: AppTextStyles.headingSmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              for (final method in CustomerPaymentMethod.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      method == CustomerPaymentMethod.wallet
                          ? Icons.account_balance_wallet_rounded
                          : Icons.payment_rounded,
                      size: 16,
                      color: method == CustomerPaymentMethod.wallet
                          ? AppColors.primary
                          : AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(method.label, style: AppTextStyles.bodySmall),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (maximum == 0)
            Text(
              PaymentStrings.noSuccessful,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(
                  56.0,
                  constraints.maxWidth / widget.buckets.length,
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < widget.buckets.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Semantics(
                            label:
                                '${widget.buckets[i].label}, '
                                '${PaymentStrings.wallet} ${formatVnd(widget.buckets[i].total(CustomerPaymentMethod.wallet))}, '
                                '${PaymentStrings.vnpay} ${formatVnd(widget.buckets[i].total(CustomerPaymentMethod.vnpay))}',
                            selected: _selected == i,
                            child: SizedBox(
                              width: width - AppSpacing.sm,
                              child: InkWell(
                                key: ValueKey('payment-bar-$i'),
                                onTap: () => setState(() => _selected = i),
                                borderRadius: AppRadius.sm,
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.xs),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: 112,
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: ClipRRect(
                                            borderRadius: AppRadius.xs,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                for (final method in [
                                                  CustomerPaymentMethod.vnpay,
                                                  CustomerPaymentMethod.wallet,
                                                ])
                                                  Container(
                                                    height:
                                                        112 *
                                                        widget.buckets[i].total(
                                                          method,
                                                        ) /
                                                        maximum,
                                                    width: AppSpacing.xl2,
                                                    color:
                                                        method ==
                                                            CustomerPaymentMethod
                                                                .wallet
                                                        ? AppColors.primary
                                                        : AppColors.accent,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        widget.buckets[i].label,
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              fontWeight: _selected == i
                                                  ? FontWeight.w800
                                                  : FontWeight.w500,
                                            ),
                                      ),
                                      if (_selected == i)
                                        const Icon(
                                          Icons.arrow_drop_up_rounded,
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          if (_selected != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '${widget.buckets[_selected!].label} · ${formatVnd(widget.buckets[_selected!].amount)}',
              style: AppTextStyles.labelMedium,
            ),
          ],
        ],
      ),
    );
  }
}
