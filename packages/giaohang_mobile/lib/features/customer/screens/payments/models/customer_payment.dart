import '../payment_strings.dart';

enum CustomerPaymentMethod {
  wallet,
  vnpay;

  String get label =>
      this == wallet ? PaymentStrings.wallet : PaymentStrings.vnpay;
}

enum CustomerPaymentState {
  completed,
  reserved,
  pending,
  refundPending,
  refunded,
  failed,
  expired,
  reversed,
  unknown;

  String get label => switch (this) {
    completed => PaymentStrings.successful,
    reserved => PaymentStrings.reserved,
    pending => PaymentStrings.pending,
    refundPending => PaymentStrings.refundPending,
    refunded => PaymentStrings.refunded,
    failed => PaymentStrings.failed,
    expired => PaymentStrings.expired,
    reversed => PaymentStrings.reversed,
    unknown => PaymentStrings.unknown,
  };
}

class CustomerPayment {
  const CustomerPayment({
    required this.id,
    required this.method,
    required this.state,
    required this.amount,
    required this.createdAt,
    this.orderId,
    this.trackingCode,
    this.providerReference,
  });

  final String id;
  final CustomerPaymentMethod method;
  final CustomerPaymentState state;
  final int amount;
  final DateTime createdAt;
  final String? orderId, trackingCode, providerReference;
  String get key => '${method.name}:$id';
  String get reference => providerReference ?? id;

  factory CustomerPayment.fromJson(
    Map<String, dynamic> row,
    CustomerPaymentMethod method,
  ) {
    final metadata = row['metadata'] as Map?;
    final order = row['order'] as Map?;
    final status = row['status'];
    final state = method == CustomerPaymentMethod.wallet
        ? status == 'reversed'
              ? CustomerPaymentState.reversed
              : status != 'completed'
              ? CustomerPaymentState.unknown
              : switch (metadata?['payment_state']) {
                  'settled' => CustomerPaymentState.completed,
                  'reserved' => CustomerPaymentState.reserved,
                  'refunded' => CustomerPaymentState.refunded,
                  _ => CustomerPaymentState.unknown,
                }
        : switch (status) {
            'paid' => CustomerPaymentState.completed,
            'pending' => CustomerPaymentState.pending,
            'refund_required' => CustomerPaymentState.refundPending,
            'refunded' => CustomerPaymentState.refunded,
            'failed' => CustomerPaymentState.failed,
            'expired' => CustomerPaymentState.expired,
            _ => CustomerPaymentState.unknown,
          };
    return CustomerPayment(
      id: row['id'] as String,
      method: method,
      state: state,
      amount: (row['amount'] as num).toInt(),
      createdAt: DateTime.parse(row['created_at'] as String),
      orderId: row['order_id'] as String?,
      trackingCode: order?['tracking_code'] as String?,
      providerReference: row['provider_txn_ref'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': switch (state) {
      CustomerPaymentState.completed =>
        method == CustomerPaymentMethod.wallet ? 'completed' : 'paid',
      CustomerPaymentState.reserved => 'completed',
      CustomerPaymentState.refunded =>
        method == CustomerPaymentMethod.wallet ? 'completed' : 'refunded',
      CustomerPaymentState.refundPending => 'refund_required',
      _ => state.name,
    },
    if (method == CustomerPaymentMethod.wallet) ...{
      'transaction_type': 'delivery_fee_payment',
      'metadata': {
        'payment_state': switch (state) {
          CustomerPaymentState.completed => 'settled',
          CustomerPaymentState.reserved => 'reserved',
          CustomerPaymentState.refunded => 'refunded',
          _ => null,
        },
      },
    } else
      'provider': 'vnpay',
    'amount': amount,
    'created_at': createdAt.toIso8601String(),
    'order_id': orderId,
    'order': {'tracking_code': trackingCode},
    'provider_txn_ref': providerReference,
  };
}
