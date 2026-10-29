import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../account/utils/customer_wallet_period.dart';
import '../../account/widgets/customer_wallet_period_controls.dart'
    show customerWalletPeriodLabel;
import '../models/customer_payment.dart';
import '../payment_strings.dart';

class PaymentPeriodControls extends StatelessWidget {
  const PaymentPeriodControls({
    super.key,
    required this.selection,
    required this.today,
    required this.method,
    required this.onPeriod,
    required this.onMethod,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
  });
  final CustomerWalletPeriodSelection selection;
  final DateTime today;
  final CustomerPaymentMethod? method;
  final ValueChanged<CustomerWalletPeriod> onPeriod;
  final ValueChanged<CustomerPaymentMethod?> onMethod;
  final VoidCallback onPrevious, onPickDate;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          for (final period in CustomerWalletPeriod.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: _Choice(
                  label: switch (period) {
                    CustomerWalletPeriod.day => PaymentStrings.day,
                    CustomerWalletPeriod.week => PaymentStrings.week,
                    CustomerWalletPeriod.month => PaymentStrings.month,
                  },
                  selected: selection.period == period,
                  onTap: () => onPeriod(period),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            tooltip: PaymentStrings.previous,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextButton(
              onPressed: onPickDate,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(48, 48),
                textStyle: AppTextStyles.labelMedium,
              ),
              child: Text(
                customerWalletPeriodLabel(selection, today),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: onNext,
            tooltip: PaymentStrings.next,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final item in <CustomerPaymentMethod?>[
            null,
            ...CustomerPaymentMethod.values,
          ])
            _Choice(
              label: item?.label ?? PaymentStrings.all,
              selected: method == item,
              onTap: () => onMethod(item),
            ),
        ],
      ),
    ],
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        foregroundColor: AppColors.primary,
        backgroundColor: selected ? AppColors.accentLight : AppColors.bgCard,
        side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        textStyle: AppTextStyles.labelMedium,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          if (selected) const Icon(Icons.check_rounded, size: 16),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
