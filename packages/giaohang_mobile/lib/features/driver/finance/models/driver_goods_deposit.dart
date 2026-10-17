import '../../../../core/models/driver_wallet.dart';

enum DriverGoodsDepositStatus {
  required,
  held,
  refundPending,
  refunded,
  verificationRequired,
}

/// Presentation contract for the paid-goods deposit flow.
/// Call with a complete per-order ledger, never the paginated wallet history.
/// This does not debit or refund the wallet.
class DriverGoodsDeposit {
  const DriverGoodsDeposit._({required this.amount, required this.status});

  static const purpose = DriverWalletTransaction.paidGoodsDepositPurpose;

  final int amount;
  final DriverGoodsDepositStatus status;

  factory DriverGoodsDeposit.fromTransactions({
    required String orderId,
    required String driverId,
    required int expectedAmount,
    required bool deliveryCompleted,
    required Iterable<DriverWalletTransaction> transactions,
  }) {
    if (expectedAmount <= 0) {
      throw ArgumentError.value(expectedAmount, 'expectedAmount');
    }
    var held = 0;
    var released = 0;
    var inconsistent = false;
    final seen = <String>{};
    for (final transaction in transactions) {
      if (transaction.orderId != orderId ||
          transaction.driverId != driverId ||
          transaction.status != 'completed' ||
          transaction.metadata['purpose'] != purpose ||
          !seen.add(transaction.id)) {
        continue;
      }
      final amount = transaction.amount;
      if (transaction.id.isEmpty) inconsistent = true;
      if (transaction.type == 'cod_hold') {
        held += amount;
        inconsistent |=
            amount <= 0 ||
            transaction.availableDelta != -amount ||
            transaction.heldDelta != amount;
      } else if (transaction.type == 'cod_release') {
        released += amount;
        inconsistent |=
            amount <= 0 ||
            transaction.availableDelta != amount ||
            transaction.heldDelta != -amount;
      } else {
        inconsistent |=
            transaction.availableDelta != 0 || transaction.heldDelta != 0;
      }
    }

    final status = switch ((held, released)) {
      _ when inconsistent => DriverGoodsDepositStatus.verificationRequired,
      (0, 0) when !deliveryCompleted => DriverGoodsDepositStatus.required,
      (final h, 0) when h == expectedAmount =>
        deliveryCompleted
            ? DriverGoodsDepositStatus.refundPending
            : DriverGoodsDepositStatus.held,
      (final h, final r) when h == expectedAmount && r == h =>
        DriverGoodsDepositStatus.refunded,
      _ => DriverGoodsDepositStatus.verificationRequired,
    };
    return DriverGoodsDeposit._(amount: expectedAmount, status: status);
  }
}
