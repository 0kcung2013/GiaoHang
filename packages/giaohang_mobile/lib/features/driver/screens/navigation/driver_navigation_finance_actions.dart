part of 'driver_navigation_screen.dart';

extension _DriverNavigationFinanceActions on _DriverNavigationScreenState {
  void _refreshOrderWallet() {
    ref.invalidate(driverWalletSummaryProvider);
    ref.invalidate(driverWalletTransactionsProvider);
    if (_currentOrder.requiresPaidGoodsDeposit &&
        _currentOrder.driverId != null) {
      ref.invalidate(
        driverOrderWalletTransactionsProvider((
          orderId: _currentOrder.id,
          driverId: _currentOrder.driverId!,
        )),
      );
    }
  }

  Future<DriverGoodsDeposit?> _loadGoodsDeposit({
    required bool deliveryCompleted,
  }) async {
    final order = _currentOrder;
    if (!order.requiresPaidGoodsDeposit || order.driverId == null) {
      return null;
    }
    try {
      final transactions = await ref
          .read(driverWalletServiceProvider)
          .getOrderTransactions(orderId: order.id, driverId: order.driverId!);
      return DriverGoodsDeposit.fromTransactions(
        orderId: order.id,
        driverId: order.driverId!,
        expectedAmount: order.driverAdvanceAmount,
        deliveryCompleted: deliveryCompleted,
        transactions: transactions,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _showPickupDepositReceipt() async {
    if (!_currentOrder.requiresPaidGoodsDeposit) return;
    final deposit = await _loadGoodsDeposit(deliveryCompleted: false);
    if (!mounted) return;
    if (deposit?.status != DriverGoodsDepositStatus.held) {
      _showWorkflowMessage(DriverGoodsDepositText.pickupUnverified);
      return;
    }
    int? balance;
    try {
      balance = (await ref.read(driverWalletServiceProvider).getSummary())
          .availableBalance;
    } catch (_) {
      // The hold receipt remains authoritative; never estimate a wallet balance.
    }
    if (!mounted) return;
    await showDriverWalletDebitDialog(
      context: context,
      debitedAmount: deposit!.amount,
      availableBalance: balance,
      isGoodsDeposit: true,
    );
  }
}
