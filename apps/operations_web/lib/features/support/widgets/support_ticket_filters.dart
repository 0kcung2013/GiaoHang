import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/support_ticket_strings.dart';
import '../models/support_ticket.dart';
import '../utils/support_ticket_ui.dart';

class SupportTicketFilters extends StatelessWidget {
  const SupportTicketFilters({
    required this.searchController,
    required this.status,
    required this.priority,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    super.key,
  });

  final TextEditingController searchController;
  final SupportTicketStatus? status;
  final SupportTicketPriority? priority;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SupportTicketStatus?> onStatusChanged;
  final ValueChanged<SupportTicketPriority?> onPriorityChanged;

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
          final search = TextField(
            key: const Key('support-ticket-search'),
            controller: searchController,
            onChanged: onSearchChanged,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: SupportTicketStrings.searchHint,
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
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
                borderSide: BorderSide(
                  color: AppColors.borderFocus,
                  width: 1.5,
                ),
              ),
            ),
          );
          final statusMenu = _TicketFilterMenu<SupportTicketStatus>(
            label: status == null
                ? SupportTicketStrings.allStatuses
                : SupportTicketUi.statusLabel(status!),
            icon: Icons.tune_rounded,
            value: status,
            items: SupportTicketStatus.values,
            itemLabel: SupportTicketUi.statusLabel,
            onChanged: onStatusChanged,
          );
          final priorityMenu = _TicketFilterMenu<SupportTicketPriority>(
            label: priority == null
                ? SupportTicketStrings.allPriorities
                : SupportTicketUi.priorityLabel(priority!),
            icon: Icons.flag_outlined,
            value: priority,
            items: SupportTicketPriority.values,
            itemLabel: SupportTicketUi.priorityLabel,
            onChanged: onPriorityChanged,
          );

          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                search,
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: statusMenu),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: priorityMenu),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(width: 180, child: statusMenu),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(width: 180, child: priorityMenu),
            ],
          );
        },
      ),
    );
  }
}

class _TicketFilterMenu<T> extends StatelessWidget {
  const _TicketFilterMenu({
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
      itemBuilder: (_) => [
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
            Icon(icon, size: 20, color: AppColors.textSecondary),
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
