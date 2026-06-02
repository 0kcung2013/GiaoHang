import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/utils/order_cargo_utils.dart';

class ServiceTypeSelector extends StatelessWidget {
  const ServiceTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SelectableOption(
          selected: value == 'standard',
          icon: Icons.inventory_2_rounded,
          title: 'Tiêu chuẩn',
          subtitle: 'Phù hợp đơn giao thông thường, ưu tiên ổn định.',
          trailing: 'Phí hiện tại',
          onTap: () => onChanged('standard'),
        ),
        const SizedBox(height: AppSpacing.md),
        _SelectableOption(
          selected: value == 'express',
          icon: Icons.bolt_rounded,
          title: 'Nhanh',
          subtitle: 'Ưu tiên xử lý sớm hơn khi có tài xế phù hợp.',
          trailing: 'Phí hiện tại',
          onTap: () => onChanged('express'),
        ),
      ],
    );
  }
}

class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return _SelectableOption(
      selected: true,
      icon: Icons.payments_rounded,
      title: 'COD / Tiền mặt',
      subtitle: 'Thanh toán trực tiếp khi giao hàng.',
      trailing: 'Đang dùng',
      onTap: () {},
    );
  }
}

class CargoCategorySelector extends StatelessWidget {
  const CargoCategorySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: cargoCategories.map((category) {
        final selected = value == category;
        return ChoiceChip(
          selected: selected,
          label: Text(cargoCategoryLabel(category)),
          labelStyle: AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.textOnAccent : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          selectedColor: AppColors.accent,
          backgroundColor: AppColors.bgLight,
          side: BorderSide(
            color: selected ? AppColors.accent : AppColors.border,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.full),
          onSelected: (_) => onChanged(category),
        );
      }).toList(),
    );
  }
}

class _SelectableOption extends StatelessWidget {
  const _SelectableOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.md,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentLight : AppColors.bgLight,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : AppColors.bgCard,
                borderRadius: AppRadius.sm,
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.textOnAccent : AppColors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.accent : AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  trailing,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: selected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
