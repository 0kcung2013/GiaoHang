import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';

class OrderListHeader extends StatelessWidget {
  const OrderListHeader({super.key, required this.onCreateOrder});

  final VoidCallback onCreateOrder;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đơn hàng',
                style: AppTextStyles.displayMedium.copyWith(
                  color: AppColors.textPrimary,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Theo dõi và quản lý các đơn giao của bạn',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Semantics(
          button: true,
          label: 'Tạo đơn hàng mới',
          child: Material(
            color: AppColors.accent,
            borderRadius: AppRadius.md,
            child: InkWell(
              onTap: onCreateOrder,
              borderRadius: AppRadius.md,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.textOnAccent,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OrderSearchBar extends StatelessWidget {
  const OrderSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Tìm mã đơn, địa chỉ hoặc người nhận',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: AppColors.bgCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
          size: 21,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Xoá tìm kiếm',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.textMuted,
              ),
        border: _searchBorder(Colors.transparent),
        enabledBorder: _searchBorder(Colors.transparent),
        focusedBorder: _searchBorder(AppColors.accent, width: 1.5),
      ),
    );
  }
}

OutlineInputBorder _searchBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: AppRadius.lg,
    borderSide: BorderSide(color: color, width: width),
  );
}

class OrderFilterBar extends StatelessWidget {
  const OrderFilterBar({
    super.key,
    required this.filters,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          return Semantics(
            button: true,
            selected: selected,
            child: Material(
              color: selected ? AppColors.primary : AppColors.bgCard,
              borderRadius: AppRadius.full,
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: AppRadius.full,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm + 1,
                  ),
                  child: Text(
                    filters[index],
                    style: AppTextStyles.labelMedium.copyWith(
                      color: selected
                          ? AppColors.textOnDark
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
