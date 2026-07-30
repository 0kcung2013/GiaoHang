import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import 'order_list_header.dart';

const orderControlsSurfaceKey = Key('order-controls-surface');
const orderCompactToolbarKey = Key('order-compact-toolbar');

Key orderFilterKey(int index) => ValueKey('order-filter-$index');

class OrderCompactToolbar extends StatelessWidget {
  const OrderCompactToolbar({
    super.key,
    required this.onCreateOrder,
    required this.controller,
    required this.onSearchChanged,
    required this.filters,
    required this.filterIcons,
    required this.selectedIndex,
    required this.onFilterSelected,
  });

  final VoidCallback onCreateOrder;
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final List<String> filters;
  final List<IconData> filterIcons;
  final int selectedIndex;
  final ValueChanged<int> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: orderCompactToolbarKey,
      height: 128,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final visualWidth = constraints.maxWidth < 320 ? 80.0 : 96.0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: visualWidth,
                child: OrderListHeader(
                  compact: true,
                  onCreateOrder: onCreateOrder,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OrderListControls(
                  compact: true,
                  controller: controller,
                  onSearchChanged: onSearchChanged,
                  filters: filters,
                  filterIcons: filterIcons,
                  selectedIndex: selectedIndex,
                  onFilterSelected: onFilterSelected,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class OrderListControls extends StatelessWidget {
  const OrderListControls({
    super.key,
    required this.controller,
    required this.onSearchChanged,
    required this.filters,
    required this.filterIcons,
    required this.selectedIndex,
    required this.onFilterSelected,
    this.compact = false,
  }) : assert(filters.length == filterIcons.length);

  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final List<String> filters;
  final List<IconData> filterIcons;
  final int selectedIndex;
  final ValueChanged<int> onFilterSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: orderControlsSurfaceKey,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: compact ? AppShadow.subtle : AppShadow.card,
      ),
      child: Column(
        children: [
          OrderSearchBar(
            compact: compact,
            controller: controller,
            onChanged: onSearchChanged,
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          OrderFilterBar(
            filters: filters,
            icons: filterIcons,
            selectedIndex: selectedIndex,
            onSelected: onFilterSelected,
            showSelectedLabel: !compact,
          ),
        ],
      ),
    );
  }
}

class OrderSearchBar extends StatelessWidget {
  const OrderSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.compact = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: 'Tìm kiếm theo mã đơn, địa chỉ hoặc người nhận',
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.accent,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: compact ? 'Tìm đơn...' : 'Mã đơn, địa chỉ, người nhận',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          filled: true,
          fillColor: AppColors.bgLight,
          contentPadding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.md : AppSpacing.lg,
            vertical: compact ? AppSpacing.sm : AppSpacing.md + 2,
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: compact ? 44 : 52,
            minHeight: compact ? 44 : 48,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.all(compact ? 6 : AppSpacing.sm),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.md,
              ),
              child: const Icon(
                Icons.search_rounded,
                color: AppColors.accent,
                size: 20,
              ),
            ),
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
                  color: AppColors.textSecondary,
                ),
          border: _searchBorder(AppColors.border),
          enabledBorder: _searchBorder(AppColors.border),
          focusedBorder: _searchBorder(AppColors.accent, width: 1.5),
        ),
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
    required this.icons,
    required this.selectedIndex,
    required this.onSelected,
    this.showSelectedLabel = true,
  }) : assert(filters.length == icons.length);

  final List<String> filters;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool showSelectedLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, _) =>
            SizedBox(width: showSelectedLabel ? AppSpacing.sm : 0),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;

          return Semantics(
            button: true,
            selected: selected,
            label: filters[index],
            child: Tooltip(
              message: filters[index],
              child: AnimatedContainer(
                duration: AppDuration.fast,
                curve: AppCurve.decelerate,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : AppColors.bgLight,
                  borderRadius: AppRadius.full,
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: AppRadius.full,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: orderFilterKey(index),
                    onTap: () => onSelected(index),
                    borderRadius: AppRadius.full,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: selected && showSelectedLabel
                            ? AppSpacing.md
                            : 14,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icons[index],
                            size: 20,
                            color: selected
                                ? AppColors.textOnAccent
                                : AppColors.textSecondary,
                          ),
                          if (selected && showSelectedLabel) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              filters[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textOnAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
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
