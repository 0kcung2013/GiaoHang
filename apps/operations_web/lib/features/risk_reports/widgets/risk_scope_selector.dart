import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/risk_report.dart';

class RiskScopeSelector extends StatelessWidget {
  const RiskScopeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final RiskScope value;
  final ValueChanged<RiskScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Phạm vi báo cáo sự cố',
      child: Row(
        children: [
          Expanded(
            child: _ScopeChoice(
              key: const Key('risk-scope-order'),
              selected: value == RiskScope.order,
              icon: Icons.inventory_2_outlined,
              title: 'Theo đơn hàng',
              subtitle: 'Sự cố ảnh hưởng một vận đơn',
              onTap: () => onChanged(RiskScope.order),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _ScopeChoice(
              key: const Key('risk-scope-system'),
              selected: value == RiskScope.system,
              icon: Icons.dns_outlined,
              title: 'Toàn hệ thống',
              subtitle: 'Lỗi nền tảng hoặc dịch vụ',
              onTap: () => onChanged(RiskScope.system),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeChoice extends StatelessWidget {
  const _ScopeChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.06)
          : AppColors.bgLight,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 94),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyles.labelMedium.copyWith(color: color),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
