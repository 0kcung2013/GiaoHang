import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../constants/return_approval_strings.dart';
import '../services/return_route_quote_service.dart';

class SupportReturnQuoteCard extends StatelessWidget {
  const SupportReturnQuoteCard({
    required this.quote,
    required this.payer,
    required this.deliveryFee,
    this.configuredReturnFee,
    super.key,
  });

  final ReturnRouteQuote quote;
  final ReturnFeePayer payer;
  final int deliveryFee;
  final int? configuredReturnFee;

  @override
  Widget build(BuildContext context) {
    final returnFee =
        configuredReturnFee ??
        OrderReturnPricingPolicy.calculateReturnFee(deliveryFee);
    final totalDriverEarning = deliveryFee + returnFee;
    final customerCharge = payer == ReturnFeePayer.customer ? returnFee : 0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FeeRow(
                  label: ReturnApprovalStrings.returnFee,
                  amount: returnFee,
                  prominent: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${payer == ReturnFeePayer.customer ? ReturnApprovalStrings.customerPays : ReturnApprovalStrings.platformPays}'
                  ' · ${ReturnApprovalStrings.extraCustomerCharge} ${_vnd(customerCharge)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _RouteValue(
                      icon: Icons.route_rounded,
                      text:
                          '${(quote.distanceMeters / 1000).toStringAsFixed(1)} km',
                    ),
                    _RouteValue(
                      icon: Icons.schedule_rounded,
                      text: '${(quote.durationSeconds / 60).ceil()} phút',
                    ),
                    if (quote.source == ReturnQuoteSource.fallback)
                      Text(
                        ReturnApprovalStrings.estimatedRoute,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ExpansionTile(
            key: const Key('return-fee-details'),
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: AppColors.accent,
            collapsedIconColor: AppColors.textSecondary,
            title: Text(
              ReturnApprovalStrings.feeDetails,
              style: AppTextStyles.labelMedium,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              _FeeRow(
                label: ReturnApprovalStrings.deliveryFee,
                amount: deliveryFee,
              ),
              const SizedBox(height: AppSpacing.sm),
              _FeeRow(
                label: ReturnApprovalStrings.driverTotal,
                amount: totalDriverEarning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({
    required this.label,
    required this.amount,
    this.prominent = false,
  });
  final String label;
  final int amount;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.xs,
    children: [
      Text(
        label,
        style: prominent ? AppTextStyles.labelLarge : AppTextStyles.bodySmall,
      ),
      Text(
        _vnd(amount),
        style: prominent
            ? AppTextStyles.headingMedium
            : AppTextStyles.labelMedium,
      ),
    ],
  );
}

class _RouteValue extends StatelessWidget {
  const _RouteValue({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: AppSpacing.sm),
      Text(text, style: AppTextStyles.bodySmall),
    ],
  );
}

String _vnd(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${buffer.toString()} đ';
}
