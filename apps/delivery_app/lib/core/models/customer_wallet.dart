class CustomerWalletSummary {
  const CustomerWalletSummary({
    required this.availableBalance,
    required this.totalReceived,
  });

  final int availableBalance;
  final int totalReceived;

  factory CustomerWalletSummary.fromJson(Map<String, dynamic> json) {
    return CustomerWalletSummary(
      availableBalance: _money(json['available_balance']),
      totalReceived: _money(json['total_received']),
    );
  }
}

class CustomerWalletTransaction {
  const CustomerWalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.availableDelta,
    required this.createdAt,
  });

  final String id;
  final String type;
  final int amount;
  final int availableDelta;
  final DateTime createdAt;

  factory CustomerWalletTransaction.fromJson(Map<String, dynamic> json) {
    return CustomerWalletTransaction(
      id: json['id']?.toString() ?? '',
      type: json['transaction_type']?.toString() ?? '',
      amount: _money(json['amount']),
      availableDelta: _money(json['available_delta']),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String get label => switch (type) {
    'delivery_credit' => 'Tiền hàng giao thành công',
    'failed_delivery_credit' => 'Bồi hoàn giao thất bại',
    'risk_credit' => 'Quyết toán đơn rủi ro',
    'adjustment_credit' => 'Điều chỉnh tăng',
    'adjustment_debit' => 'Điều chỉnh giảm',
    _ => 'Giao dịch COD',
  };
}

int _money(Object? value) =>
    value is num ? value.round() : num.tryParse('$value')?.round() ?? 0;
