import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/risk_report_strings.dart';
import '../models/risk_report.dart';
import '../utils/risk_report_ui.dart';

class RiskReportFilters extends StatelessWidget {
  const RiskReportFilters({
    required this.searchController,
    required this.selectedSeverity,
    required this.selectedStatus,
    required this.onSearchChanged,
    required this.onSeverityChanged,
    required this.onStatusChanged,
    this.showSeverity = true,
    this.showStatus = true,
    super.key,
  });

  final TextEditingController searchController;
  final RiskSeverity? selectedSeverity;
  final RiskStatus? selectedStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<RiskSeverity?> onSeverityChanged;
  final ValueChanged<RiskStatus?> onStatusChanged;
  final bool showSeverity;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final search = _SearchField(
            controller: searchController,
            onChanged: onSearchChanged,
          );
          final severity = _FilterMenu<RiskSeverity>(
            label: selectedSeverity == null
                ? 'Mức độ'
                : RiskReportUi.severityLabel(selectedSeverity!),
            icon: Icons.warning_amber_rounded,
            value: selectedSeverity,
            items: RiskSeverity.values,
            itemLabel: RiskReportUi.severityLabel,
            onChanged: onSeverityChanged,
          );
          final status = _FilterMenu<RiskStatus>(
            label: selectedStatus == null
                ? 'Trạng thái'
                : RiskReportUi.statusLabel(selectedStatus!),
            icon: Icons.tune_rounded,
            value: selectedStatus,
            items: RiskStatus.values,
            itemLabel: RiskReportUi.statusLabel,
            onChanged: onStatusChanged,
          );

          if (!showSeverity && !showStatus) return search;

          if (compact) {
            return Column(
              children: [
                search,
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    if (showSeverity) ...[
                      Expanded(child: severity),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    if (showStatus) Expanded(child: status),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              if (showSeverity) ...[
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 170, child: severity),
              ],
              if (showStatus) ...[
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 180, child: status),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('risk-search-field'),
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: RiskReportStrings.searchHint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textMuted,
        ),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Xóa tìm kiếm',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: AppColors.bgLight,
        border: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T?>(
      tooltip: label,
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem<T?>(value: null, child: const Text('Tất cả')),
        ...items.map(
          (item) =>
              PopupMenuItem<T?>(value: item, child: Text(itemLabel(item))),
        ),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: value == null ? AppColors.bgLight : AppColors.accentLight,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: value == null ? AppColors.border : AppColors.accent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
