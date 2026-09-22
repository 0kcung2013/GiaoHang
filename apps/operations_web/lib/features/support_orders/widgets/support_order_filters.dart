import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/support_order.dart';

class SupportOrderFilters extends StatelessWidget {
  const SupportOrderFilters({
    required this.searchController,
    required this.scope,
    required this.resultCount,
    required this.onSearchChanged,
    required this.onScopeChanged,
    required this.onClearSearch,
    super.key,
  });

  final TextEditingController searchController;
  final SupportOrderScope scope;
  final int resultCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SupportOrderScope> onScopeChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tra cứu theo mã đơn',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$resultCount kết quả',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('support-order-search'),
            controller: searchController,
            onChanged: onSearchChanged,
            textCapitalization: TextCapitalization.characters,
            style: AppTextStyles.mono.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Nhập mã đơn, ví dụ GH-10248',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa mã đơn',
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppColors.bgLight,
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: SupportOrderScope.values.map((item) {
                final selected = item == scope;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: 'Lọc ${item.label}',
                    child: ChoiceChip(
                      key: Key('support-order-scope-${item.name}'),
                      selected: selected,
                      onSelected: (_) => onScopeChanged(item),
                      avatar: Icon(
                        _scopeIcon(item),
                        size: 18,
                        color: selected
                            ? AppColors.textOnAccent
                            : AppColors.textSecondary,
                      ),
                      label: Text(item.label),
                      showCheckmark: false,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.bgLight,
                      side: BorderSide(
                        color: selected ? AppColors.accent : AppColors.border,
                      ),
                      labelStyle: AppTextStyles.labelMedium.copyWith(
                        color: selected
                            ? AppColors.textOnAccent
                            : AppColors.textSecondary,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.full,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _scopeIcon(SupportOrderScope scope) => switch (scope) {
    SupportOrderScope.all => Icons.inventory_2_outlined,
    SupportOrderScope.active => Icons.local_shipping_outlined,
    SupportOrderScope.completed => Icons.check_circle_outline_rounded,
    SupportOrderScope.attention => Icons.report_gmailerrorred_rounded,
  };
}
