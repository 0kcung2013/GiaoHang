import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../../../core/models/driver_wallet.dart';
import '../utils/driver_wallet_period.dart';
import 'wallet_balance_hero.dart';
import 'wallet_period_controls.dart';
import 'wallet_transaction_list.dart';

class DriverWalletContent extends StatefulWidget {
  const DriverWalletContent({
    super.key,
    required this.summary,
    required this.transactions,
    required this.onTopUp,
    this.now,
  });

  final DriverWalletSummary summary;
  final List<DriverWalletTransaction> transactions;
  final VoidCallback onTopUp;
  final DateTime? now;

  @override
  State<DriverWalletContent> createState() => _DriverWalletContentState();
}

class _DriverWalletContentState extends State<DriverWalletContent> {
  late final DateTime _today;
  late DriverWalletPeriodSelection _selection;

  @override
  void initState() {
    super.initState();
    _today = VietnamTime.now(clock: widget.now);
    _selection = DriverWalletPeriodSelection(
      period: DriverWalletPeriod.day,
      anchorDate: _today,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleTransactions = widget.transactions
        .where((transaction) => transaction.isVisibleInHistory)
        .toList();
    final filteredTransactions = _selection.filter(visibleTransactions);
    final todaySelection = DriverWalletPeriodSelection(
      period: DriverWalletPeriod.day,
      anchorDate: _today,
    );
    final todayIncome = todaySelection.income(
      todaySelection.filter(visibleTransactions),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.xl4,
      ),
      children: [
        WalletBalanceHero(
          summary: widget.summary,
          todayIncome: todayIncome,
          onTopUp: widget.onTopUp,
        ),
        const SizedBox(height: AppSpacing.xl2),
        WalletPeriodControls(
          selection: _selection,
          today: _today,
          onPeriodChanged: _changePeriod,
          onPrevious: () => _shiftPeriod(-1),
          onNext: _canMoveForward ? () => _shiftPeriod(1) : null,
          onPickDate: _pickDate,
        ),
        const SizedBox(height: AppSpacing.md),
        WalletPeriodSummary(
          incomeText: formatVnd(_selection.income(filteredTransactions)),
          transactionCount: filteredTransactions.length,
        ),
        const SizedBox(height: AppSpacing.xl2),
        Text(
          'Giao dịch theo ngày',
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        WalletTransactionList(
          transactions: filteredTransactions,
          today: _today,
        ),
      ],
    );
  }

  bool get _canMoveForward {
    final currentPeriod = DriverWalletPeriodSelection(
      period: _selection.period,
      anchorDate: _today,
    );
    return _selection.start.isBefore(currentPeriod.start);
  }

  void _changePeriod(DriverWalletPeriod period) {
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
      _selection = DriverWalletPeriodSelection(
        period: _selection.period,
        anchorDate: selected,
      );
    });
  }
}
