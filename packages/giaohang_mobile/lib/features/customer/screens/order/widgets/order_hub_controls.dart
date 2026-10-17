import '../utils/order_hub_strings.dart';
import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../utils/order_history_filter.dart';
import 'order_list_controls.dart';
import 'order_list_header.dart';

class OrderHubControls extends StatelessWidget {
  const OrderHubControls({
    super.key,
    required this.controller,
    required this.history,
    required this.onSearch,
    required this.onTab,
    required this.onCreate,
  });
  final TextEditingController controller;
  final bool history;
  final ValueChanged<String> onSearch;
  final ValueChanged<bool> onTab;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.xl,
      border: Border.all(color: AppColors.border),
      boxShadow: AppShadow.subtle,
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OrderSearchBar(
                controller: controller,
                onChanged: onSearch,
                compact: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              key: orderCreateActionKey,
              tooltip: OrderHubStrings.create,
              onPressed: onCreate,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _Tab(
                label: OrderHubStrings.active,
                selected: !history,
                onTap: () => onTab(false),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Tab(
                label: OrderHubStrings.history,
                selected: history,
                onTap: () => onTab(true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({
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
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.textPrimary,
        backgroundColor: selected ? AppColors.accentLight : AppColors.bgLight,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.md,
          side: BorderSide(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        textStyle: AppTextStyles.labelMedium,
      ),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

class OrderHistoryControls extends StatelessWidget {
  const OrderHistoryControls({
    super.key,
    required this.filter,
    required this.onChanged,
  });
  final OrderHistoryFilter filter;
  final ValueChanged<OrderHistoryFilter> onChanged;

  Future<void> _pick(BuildContext context, bool range) async {
    final today = calendarDay(DateTime.now());
    final initial = filter.start ?? today;
    final first = DateTime(1970);
    if (range) {
      final result = await showDateRangePicker(
        context: context,
        firstDate: first,
        lastDate: today,
        initialDateRange: filter.start == null
            ? null
            : DateTimeRange(start: initial, end: filter.end ?? initial),
        helpText: OrderHubStrings.pickCreatedRange,
        saveText: OrderHubStrings.apply,
        cancelText: OrderHubStrings.cancel,
        fieldStartHintText: OrderHubStrings.startDate,
        fieldEndHintText: OrderHubStrings.endDate,
        builder: _pickerTheme,
      );
      if (result != null) {
        onChanged(
          filter.withPeriod(
            OrderPeriod.custom,
            start: result.start,
            end: result.end,
          ),
        );
      }
    } else {
      final result = await showDatePicker(
        context: context,
        firstDate: first,
        lastDate: today,
        initialDate: initial,
        helpText: OrderHubStrings.pickCreatedDate,
        confirmText: OrderHubStrings.apply,
        cancelText: OrderHubStrings.cancel,
        builder: _pickerTheme,
      );
      if (result != null) {
        onChanged(
          filter.withPeriod(OrderPeriod.custom, start: result, end: result),
        );
      }
    }
  }

  Widget _pickerTheme(BuildContext context, Widget? child) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.bgCard,
      ),
      textTheme: Theme.of(
        context,
      ).textTheme.apply(fontFamily: AppTextStyles.bodyMedium.fontFamily),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.bgCard,
        headerBackgroundColor: AppColors.accentLight,
        headerForegroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
      ),
    ),
    child: child!,
  );

  @override
  Widget build(BuildContext context) {
    final customLabel = filter.start == null
        ? ''
        : filter.start == filter.end
        ? orderHistoryDate(filter.start!)
        : '${orderHistoryDate(filter.start!)} – ${orderHistoryDate(filter.end!)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final period in OrderPeriod.values.where(
                (value) => value != OrderPeriod.custom,
              ))
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(period.label),
                    selected: filter.period == period,
                    onSelected: (_) => onChanged(filter.withPeriod(period)),
                    selectedColor: AppColors.accentLight,
                    backgroundColor: AppColors.bgCard,
                    labelStyle: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    side: BorderSide(
                      color: filter.period == period
                          ? AppColors.accent
                          : AppColors.border,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.full,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PopupMenuButton<bool>(
              tooltip: OrderHubStrings.pickCreatedDate,
              onSelected: (range) => _pick(context, range),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: false,
                  child: Text(OrderHubStrings.singleDay),
                ),
                PopupMenuItem(
                  value: true,
                  child: Text(OrderHubStrings.dateRange),
                ),
              ],
              child: _FilterLabel(
                icon: Icons.calendar_month_rounded,
                label: OrderHubStrings.pickDate,
                active: filter.period == OrderPeriod.custom,
              ),
            ),
            PopupMenuButton<OrderHistoryStatus>(
              tooltip: OrderHubStrings.filterStatus,
              initialValue: filter.status,
              onSelected: (status) => onChanged(filter.withStatus(status)),
              itemBuilder: (_) => [
                for (final status in OrderHistoryStatus.values)
                  CheckedPopupMenuItem(
                    value: status,
                    checked: filter.status == status,
                    child: Text(status.label),
                  ),
              ],
              child: _FilterLabel(
                icon: Icons.filter_list_rounded,
                label: filter.status.label,
                active: filter.status != OrderHistoryStatus.all,
              ),
            ),
          ],
        ),
        if (filter.period == OrderPeriod.custom && filter.start != null)
          Container(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: AppRadius.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(customLabel, style: AppTextStyles.labelMedium),
                ),
                IconButton(
                  tooltip: OrderHubStrings.clearDate,
                  onPressed: () =>
                      onChanged(filter.withPeriod(OrderPeriod.all)),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel({
    required this.icon,
    required this.label,
    required this.active,
  });
  final IconData icon;
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: active ? AppColors.accent : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    ),
  );
}
