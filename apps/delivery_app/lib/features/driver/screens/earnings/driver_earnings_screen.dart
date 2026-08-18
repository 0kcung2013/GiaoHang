import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../core/providers/driver_wallet_providers.dart';
import 'widgets/driver_wallet_content.dart';
import 'widgets/wallet_topup_sheet.dart';

class DriverEarningsScreen extends ConsumerStatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  ConsumerState<DriverEarningsScreen> createState() =>
      _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends ConsumerState<DriverEarningsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(driverWalletChangesProvider, (previous, next) {
      final previousRevision = previous?.valueOrNull;
      final nextRevision = next.valueOrNull;
      if (previousRevision != null &&
          nextRevision != null &&
          previousRevision != nextRevision) {
        _refresh();
      }
    });
    final summary = ref.watch(driverWalletSummaryProvider);
    final transactions = ref.watch(driverWalletTransactionsProvider);
    if (summary.hasError || transactions.hasError) {
      return Center(
        child: IconButton.filledTonal(
          tooltip: 'Tải lại ví',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
    }
    final wallet = summary.valueOrNull;
    final history = transactions.valueOrNull;
    if (wallet == null || history == null) {
      return const Center(
        child: Icon(
          Icons.account_balance_wallet_rounded,
          color: AppColors.textMuted,
          size: 42,
        ),
      );
    }
    return DriverWalletContent(
      summary: wallet,
      transactions: history,
      onTopUp: _topUp,
    );
  }

  void _refresh() {
    ref.invalidate(driverWalletSummaryProvider);
    ref.invalidate(driverWalletTransactionsProvider);
  }

  Future<void> _topUp() async {
    final amount = await showWalletTopupSheet(context);
    if (amount == null || !mounted) return;
    try {
      final uri = await ref
          .read(driverWalletServiceProvider)
          .createTopupPaymentUrl(amount);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('Không mở được VNPAY.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
