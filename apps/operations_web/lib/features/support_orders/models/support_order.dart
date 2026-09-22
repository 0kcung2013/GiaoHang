class SupportOrder {
  const SupportOrder({
    required this.id,
    required this.trackingCode,
    required this.status,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.createdAt,
    required this.updatedAt,
    this.totalPrice = 0,
    this.deliveryFee = 0,
    this.recipientName,
    this.recipientPhone,
    this.itemName,
    this.note,
    this.paymentMethod,
    this.customerId,
    this.driverId,
  });

  final String id;
  final String trackingCode;
  final String status;
  final String pickupAddress;
  final String deliveryAddress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final num totalPrice;
  final num deliveryFee;
  final String? recipientName;
  final String? recipientPhone;
  final String? itemName;
  final String? note;
  final String? paymentMethod;
  final String? customerId;
  final String? driverId;

  factory SupportOrder.fromJson(Map<String, dynamic> json) {
    return SupportOrder(
      id: json['id']?.toString() ?? '',
      trackingCode: json['tracking_code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      pickupAddress: json['pickup_address']?.toString() ?? '',
      deliveryAddress: json['delivery_address']?.toString() ?? '',
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      totalPrice: json['total_price'] as num? ?? 0,
      deliveryFee: json['delivery_fee'] as num? ?? 0,
      recipientName: json['recipient_name']?.toString(),
      recipientPhone: json['recipient_phone']?.toString(),
      itemName: json['item_name']?.toString(),
      note: json['note']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      customerId: json['customer_id']?.toString(),
      driverId: json['driver_id']?.toString(),
    );
  }

  static DateTime _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

class SupportOrderStatusLog {
  const SupportOrderStatusLog({
    required this.status,
    required this.createdAt,
    this.title,
    this.description,
  });

  final String status;
  final DateTime createdAt;
  final String? title;
  final String? description;

  factory SupportOrderStatusLog.fromJson(Map<String, dynamic> json) {
    return SupportOrderStatusLog(
      status: json['status']?.toString() ?? '',
      createdAt: SupportOrder._date(json['created_at']),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
    );
  }
}

enum SupportOrderScope {
  all,
  active,
  completed,
  attention;

  bool includes(String status) => switch (this) {
    SupportOrderScope.all => true,
    SupportOrderScope.active => const {
      'pending',
      'confirmed',
      'assigned',
      'picking_up',
      'delivering',
    }.contains(status),
    SupportOrderScope.completed => const {
      'delivered',
      'returned',
    }.contains(status),
    SupportOrderScope.attention => const {
      'risk_hold',
      'return_approved',
      'returning',
      'cancelled',
    }.contains(status),
  };

  String get label => switch (this) {
    SupportOrderScope.all => 'Tất cả',
    SupportOrderScope.active => 'Đang xử lý',
    SupportOrderScope.completed => 'Hoàn tất',
    SupportOrderScope.attention => 'Cần chú ý',
  };
}
