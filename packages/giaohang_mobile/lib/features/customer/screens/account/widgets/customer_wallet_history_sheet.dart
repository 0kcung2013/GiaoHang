import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../../../core/models/customer_wallet.dart';
import '../utils/customer_wallet_period.dart';
import 'customer_wallet_period_controls.dart';
import 'customer_wallet_transaction_list.dart';

Future<void> showCustomerWalletHistorySheet(
  BuildContext context, {
  required CustomerWalletSummary summary,
  required List<CustomerWalletTransaction> transactions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.primary.withValues(alpha: 0.42),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.82,
      child: _WalletHistorySheet(summary: summary, transactions: transactions),
    ),
  );
}

class _WalletHistorySheet extends StatefulWidget {
  const _WalletHistorySheet({
    required this.summary,
    required this.transactions,
  });

  final CustomerWalletSummary summary;
  final List<CustomerWalletTransaction> transactions;

  @override
  State<_WalletHistorySheet> createState() => _WalletHistorySheetState();
}

class _WalletHistorySheetState extends State<_WalletHistorySheet> {
  late final DateTime _today;
  late CustomerWalletPeriodSelection _selection;

  @override
  void initState() {
    super.initState();
    _today = VietnamTime.now();
    _selection = CustomerWalletPeriodSelection(
      period: CustomerWalletPeriod.day,
      anchorDate: _today,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _selection.filter(widget.transactions);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          const _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lịch sử giao dịch',
                        style: AppTextStyles.headingLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Khả dụng ${formatVnd(widget.summary.availableBalance)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Đóng',
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(48),
                    foregroundColor: AppColors.textSecondary,
                    backgroundColor: AppColors.bgCard,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: CustomerWalletPeriodControls(
              selection: _selection,
              today: _today,
              onPeriodChanged: _changePeriod,
              onPrevious: () => _shiftPeriod(-1),
              onNext: _canMoveForward ? () => _shiftPeriod(1) : null,
              onPickDate: _pickDate,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: CustomerWalletPeriodSummary(
              transactionCount: filteredTransactions.length,
              receivedText: formatVnd(
                _selection.received(filteredTransactions),
              ),
              spentText: formatVnd(_selection.spent(filteredTransactions)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: CustomerWalletTransactionList(
              transactions: filteredTransactions,
              today: _today,
            ),
          ),
        ],
      ),
    );
  }

  bool get _canMoveForward {
    final currentPeriod = CustomerWalletPeriodSelection(
      period: _selection.period,
      anchorDate: _today,
    );
    return _selection.start.isBefore(currentPeriod.start);
  }

  void _changePeriod(CustomerWalletPeriod period) {
    setState(() => _selection = _selection.withPeriod(period));
  }

  void _shiftPeriod(int amount) {
    setState(() => _selection = _selection.shift(amount));
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selection.anchorDate.isAfter(_today)
          ? _today
          : _selection.anchorDate,
      firstDate: DateTime(2020),
      lastDate: _today,
      helpText: 'Chọn ngày xem giao dịch',
      cancelText: 'Huỷ',
      confirmText: 'Chọn',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.accent,
            secondary: AppColors.accent,
          ),
        ),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selection = CustomerWalletPeriodSelection(
        period: _selection.period,
        anchorDate: selected,
      );
    });
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 4,
        decoration: const BoxDecoration(
          color: AppColors.border,
          borderRadius: AppRadius.full,
        ),
      ),
    );
  }
}
