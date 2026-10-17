import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../../../core/models/driver_wallet.dart';
import 'driver_finance_tabs.dart';
import 'driver_income_content.dart';
import 'wallet_balance_hero.dart';
import 'wallet_transaction_list.dart';

class DriverWalletContent extends StatefulWidget {
  const DriverWalletContent({
    super.key,
    required this.summary,
    required this.transactions,
    required this.onTopUp,
    this.onWithdraw,
    this.now,
  });

  final DriverWalletSummary summary;
  final List<DriverWalletTransaction> transactions;
  final VoidCallback onTopUp;
  final VoidCallback? onWithdraw;
  final DateTime? now;

  @override
  State<DriverWalletContent> createState() => _DriverWalletContentState();
}

class _DriverWalletContentState extends State<DriverWalletContent> {
  late final DateTime _today;
  DriverFinanceTab _selectedTab = DriverFinanceTab.wallet;

  @override
  void initState() {
    super.initState();
    _today = VietnamTime.now(clock: widget.now);
  }

  @override
  Widget build(BuildContext context) {
    final visibleTransactions =
        widget.transactions
            .where((transaction) => transaction.isVisibleInHistory)
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.xl4,
      ),
      children: [
        DriverFinanceTabs(
          selected: _selectedTab,
          onChanged: (tab) => setState(() => _selectedTab = tab),
        ),
        const SizedBox(height: AppSpacing.xl2),
        AnimatedSwitcher(
          duration: AppDuration.normal,
          switchInCurve: AppCurve.decelerate,
          switchOutCurve: AppCurve.accelerate,
          child: _selectedTab == DriverFinanceTab.wallet
              ? _WalletTabContent(
                  key: const ValueKey('driver-wallet-tab'),
                  summary: widget.summary,
                  transactions: visibleTransactions,
                  today: _today,
                  onTopUp: widget.onTopUp,
                  onWithdraw: widget.onWithdraw,
                )
              : DriverIncomeContent(
                  key: const ValueKey('driver-income-tab'),
                  transactions: visibleTransactions,
                  today: _today,
                ),
        ),
      ],
    );
  }
}

class _WalletTabContent extends StatelessWidget {
  const _WalletTabContent({
    super.key,
    required this.summary,
    required this.transactions,
    required this.today,
    required this.onTopUp,
    this.onWithdraw,
  });

  final DriverWalletSummary summary;
  final List<DriverWalletTransaction> transactions;
  final DateTime today;
  final VoidCallback onTopUp;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WalletBalanceHero(
          summary: summary,
          onTopUp: onTopUp,
          onWithdraw: onWithdraw,
        ),
        const SizedBox(height: AppSpacing.xl2),
        Row(
          children: [
            Expanded(
              child: Text(
                'Lịch sử ví',
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${transactions.length} giao dịch',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        WalletTransactionList(transactions: transactions, today: today),
      ],
    );
  }
}
