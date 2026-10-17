import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../utils/order_payment_strings.dart';

class OrderPaymentChoices extends StatelessWidget {
  const OrderPaymentChoices({
    super.key,
    required this.collectCod,
    required this.onChanged,
  });
  final bool collectCod;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _Choice(
            label: OrderPaymentText.noCollection,
            selected: !collectCod,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _Choice(
            label: OrderPaymentText.collect,
            selected: collectCod,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    ),
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
    button: true,
    child: Material(
      color: selected ? AppColors.accentLight : AppColors.bgLight,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelMedium,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
