import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

enum DriverFinanceTab { wallet, income }

class DriverFinanceTabs extends StatelessWidget {
  const DriverFinanceTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DriverFinanceTab selected;
  final ValueChanged<DriverFinanceTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Row(
        children: [
          Expanded(
            child: _FinanceTabButton(
              label: 'Ví',
              icon: Icons.account_balance_wallet_rounded,
              selected: selected == DriverFinanceTab.wallet,
              onTap: () => onChanged(DriverFinanceTab.wallet),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _FinanceTabButton(
              label: 'Thu nhập',
              icon: Icons.bar_chart_rounded,
              selected: selected == DriverFinanceTab.income,
              onTap: () => onChanged(DriverFinanceTab.income),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceTabButton extends StatelessWidget {
  const _FinanceTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Mở tab $label',
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? AppColors.textOnDark
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: selected
                          ? AppColors.textOnDark
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
