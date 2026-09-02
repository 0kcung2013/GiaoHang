class DriverWalletSummary {
  const DriverWalletSummary({
    required this.availableBalance,
    required this.heldBalance,
    required this.todayIncome,
  });

  final int availableBalance;
  final int heldBalance;
  final int todayIncome;

  factory DriverWalletSummary.fromJson(Map<String, dynamic> json) {
    return DriverWalletSummary(
      availableBalance: _money(json['available_balance']),
      heldBalance: _money(json['held_balance']),
      todayIncome: _money(json['today_income']),
    );
  }

  static int _money(Object? value) =>
      value is num ? value.round() : num.tryParse('$value')?.round() ?? 0;
}

class DriverWalletTransaction {
  const DriverWalletTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.availableDelta,
    required this.heldDelta,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String status;
  final int amount;
  final int availableDelta;
  final int heldDelta;
  final DateTime createdAt;

  factory DriverWalletTransaction.fromJson(Map<String, dynamic> json) {
    int money(Object? value) =>
        value is num ? value.round() : num.tryParse('$value')?.round() ?? 0;
    return DriverWalletTransaction(
      id: json['id']?.toString() ?? '',
      type: json['transaction_type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      amount: money(json['amount']),
      availableDelta: money(json['available_delta']),
      heldDelta: money(json['held_delta']),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  int get signedAmount {
    if (availableDelta != 0) return availableDelta;
    return switch (type) {
      'cod_hold' || 'platform_fee_capture' => -amount,
      'cod_advance_capture' => 0,
      _ => amount,
    };
  }

  bool get isIncome =>
      status == 'completed' &&
      (type == 'prepaid_earning' ||
          type == 'cod_settlement' ||
          type == 'return_delivery_earning' ||
          type == 'return_earning');

  /// Capture cũ chỉ chuyển khoản đã giữ nên không hiện lần trừ thứ hai.
  /// Capture mới trừ trực tiếp số dư tại pickup và phải xuất hiện trong lịch sử.
  bool get isVisibleInHistory =>
      type != 'cod_advance_capture' || availableDelta < 0;

  String get label => switch (type) {
    'vnpay_topup' => 'Nạp ví',
    'cod_hold' => 'Ứng tiền hàng',
    'cod_release' => 'Hoàn tiền ứng COD',
    'cod_advance_capture' => 'Ứng tiền khi nhận hàng',
    'platform_fee_capture' => 'Phí nền tảng (chính sách cũ)',
    'prepaid_earning' => 'Thu nhập trả trước',
    'cod_settlement' => 'Thu nhập COD',
    'return_delivery_earning' => 'Cước giao của đơn hoàn',
    'return_earning' => 'Phí hoàn hàng',
    _ => 'Giao dịch ví',
  };
}
