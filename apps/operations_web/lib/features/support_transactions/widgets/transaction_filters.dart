import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/transaction_strings.dart';
import '../data/transaction_controller.dart';
import '../models/support_transaction.dart';
import '../utils/transaction_ui.dart';

class TransactionFilters extends StatefulWidget {
  const TransactionFilters({
    required this.controller,
    required this.searchController,
    super.key,
  });
  final TransactionController controller;
  final TextEditingController searchController;
  @override
  State<TransactionFilters> createState() => _TransactionFiltersState();
}

class _TransactionFiltersState extends State<TransactionFilters> {
  String _date = 'all';
  int _dateRevision = 0;
  DateTimeRange? _range;
  Future<void> _dates(String value) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? start, end;
    if (value == 'custom') {
      final range = await showDateRangePicker(
        context: context,
        initialDateRange: _range,
        firstDate: DateTime(2020),
        lastDate: today,
        helpText: TransactionStrings.datesLabel,
      );
      if (!mounted) return;
      if (range == null) {
        setState(() {
          _dateRevision++;
        });
        return;
      }
      _range = range;
      start = range.start;
      end = DateTime(range.end.year, range.end.month, range.end.day + 1);
    } else if (value != 'all') {
      start = DateTime(
        today.year,
        today.month,
        today.day -
            (value == 'today'
                ? 0
                : value == '7'
                ? 6
                : 29),
      );
      end = DateTime(today.year, today.month, today.day + 1);
    }
    setState(() => _date = value);
    widget.controller.changeDates(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final group in TransactionGroup.values)
                ChoiceChip(
                  label: Text(TransactionUi.group(group)),
                  selected: controller.group == group,
                  selectedColor: AppColors.accentLight,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.sm,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => controller.changeGroup(group),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const Key('transaction-search'),
            controller: widget.searchController,
            maxLength: 120,
            onChanged: controller.changeSearch,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              labelText: TransactionStrings.search,
              counterText: '',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: widget.searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: TransactionStrings.clearSearch,
                      onPressed: () {
                        widget.searchController.clear();
                        controller.changeSearch('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppColors.bgLight,
              border: const OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth < 480 ? c.maxWidth : 240.0;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        'transaction-status-${controller.group.name}-${controller.status}',
                      ),
                      initialValue: controller.status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: TransactionStrings.status,
                      ),
                      items: [
                        for (final status in [
                          'all',
                          'pending',
                          'completed',
                          'failed',
                          'expired',
                          'refund_required',
                          'refunded',
                          'reversed',
                        ])
                          DropdownMenuItem(
                            value: status,
                            child: Text(
                              status == 'all'
                                  ? TransactionStrings.allStatuses
                                  : TransactionUi.status(status),
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) controller.changeStatus(v);
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('transaction-dates-$_date:$_dateRevision'),
                      initialValue: _date,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: TransactionStrings.datesLabel,
                      ),
                      items: [
                        for (final item in [
                          ('all', TransactionStrings.allDates),
                          ('today', TransactionStrings.today),
                          ('7', TransactionStrings.sevenDays),
                          ('30', TransactionStrings.thirtyDays),
                          ('custom', TransactionStrings.customDates),
                        ])
                          DropdownMenuItem(
                            value: item.$1,
                            child: Text(item.$2),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) _dates(v);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          if (_date == 'custom' && _range != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '${TransactionUi.date(_range!.start)} – ${TransactionUi.date(_range!.end)}',
                style: AppTextStyles.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
