import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/driver_wallet.dart';
import '../utils/driver_income_breakdown.dart';
import '../utils/driver_wallet_period.dart';
import 'driver_income_chart.dart';
import 'wallet_period_controls.dart';
import 'wallet_transaction_list.dart';

class DriverIncomeContent extends StatefulWidget {
  const DriverIncomeContent({
    super.key,
    required this.transactions,
    required this.today,
  });

  final List<DriverWalletTransaction> transactions;
  final DateTime today;

  @override
  State<DriverIncomeContent> createState() => _DriverIncomeContentState();
}

class _DriverIncomeContentState extends State<DriverIncomeContent> {
  late DriverWalletPeriodSelection _selection;

  @override
  void initState() {
    super.initState();
    _selection = DriverWalletPeriodSelection(
      period: DriverWalletPeriod.week,
      anchorDate: widget.today,
    );
  }

  @override
  Widget build(BuildContext context) {
    final incomeTransactions = _selection
        .filter(widget.transactions)
        .where((transaction) => transaction.isIncome)
        .toList();
    final totalIncome = _selection.income(incomeTransactions);
    final buckets = buildDriverIncomeBreakdown(
      selection: _selection,
      transactions: incomeTransactions,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WalletPeriodControls(
          selection: _selection,
          today: widget.today,
          onPeriodChanged: _changePeriod,
          onPrevious: () => _shiftPeriod(-1),
          onNext: _canMoveForward ? () => _shiftPeriod(1) : null,
          onPickDate: _pickDate,
        ),
        const SizedBox(height: AppSpacing.sm),
        _UpdatedAtLabel(now: widget.today),
        const SizedBox(height: AppSpacing.md),
        DriverIncomeChart(buckets: buckets, totalIncome: totalIncome),
        const SizedBox(height: AppSpacing.xl2),
        Row(
          children: [
            Expanded(
              child: Text(
                'Thu nhập theo giao dịch',
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${incomeTransactions.length} khoản',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        WalletTransactionList(
          transactions: incomeTransactions,
          today: widget.today,
          emptyMessage: 'Chưa có thu nhập trong kỳ này',
        ),
      ],
    );
  }

  bool get _canMoveForward {
    final currentPeriod = DriverWalletPeriodSelection(
      period: _selection.period,
      anchorDate: widget.today,
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
      initialDate: _selection.anchorDate.isAfter(widget.today)
          ? widget.today
          : _selection.anchorDate,
      firstDate: DateTime(2020),
      lastDate: widget.today,
      helpText: 'Chọn ngày xem thu nhập',
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

class _UpdatedAtLabel extends StatelessWidget {
  const _UpdatedAtLabel({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final local = now;
    String two(int value) => value.toString().padLeft(2, '0');
    final label =
        'Cập nhật ${two(local.hour)}:${two(local.minute)} · '
        '${two(local.day)}/${two(local.month)}/${local.year}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.sync_rounded, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}
