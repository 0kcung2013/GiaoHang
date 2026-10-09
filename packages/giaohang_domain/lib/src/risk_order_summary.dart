class RiskOrderSummary {
  const RiskOrderSummary({
    required this.trackingCode,
    required this.status,
    required this.pickupAddress,
    required this.deliveryAddress,
    this.customerId,
    this.driverId,
    this.pickupLat,
    this.pickupLng,
    this.deliveryLat,
    this.deliveryLng,
    this.deliveryFee = 0,
    this.customer,
    this.driver,
    this.recipientName,
    this.recipientPhone,
    this.actualPickedUpAt,
  });

  final String trackingCode;
  final String status;
  final String pickupAddress;
  final String deliveryAddress;
  final String? customerId;
  final String? driverId;
  final double? pickupLat;
  final double? pickupLng;
  final double? deliveryLat;
  final double? deliveryLng;
  final int deliveryFee;
  final RiskContact? customer;
  final RiskContact? driver;
  final String? recipientName;
  final String? recipientPhone;
  final DateTime? actualPickedUpAt;

  bool get hasPickedUp =>
      actualPickedUpAt != null ||
      const [
        'delivering',
        'delivered',
        'return_approved',
        'returning',
        'returned',
      ].contains(status);

  factory RiskOrderSummary.fromJson(Map<String, dynamic> json) {
    return RiskOrderSummary(
      customer: RiskContact.fromNestedJson(json['customer']),
      driver: RiskContact.fromNestedJson(json['driver']),
      recipientName: json['recipient_name']?.toString(),
      recipientPhone: json['recipient_phone']?.toString(),
      trackingCode: json['tracking_code']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      pickupAddress: json['pickup_address']?.toString() ?? '',
      deliveryAddress: json['delivery_address']?.toString() ?? '',
      customerId: json['customer_id']?.toString(),
      driverId: json['driver_id']?.toString(),
      pickupLat: _optionalDouble(json['pickup_lat']),
      pickupLng: _optionalDouble(json['pickup_lng']),
      deliveryLat: _optionalDouble(json['delivery_lat']),
      deliveryLng: _optionalDouble(json['delivery_lng']),
      deliveryFee: (json['delivery_fee'] as num?)?.round() ?? 0,
      actualPickedUpAt: DateTime.tryParse(
        json['actual_picked_up_at']?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'customer': customer?.toJson(),
    'driver': driver?.toJson(),
    'recipient_name': recipientName,
    'recipient_phone': recipientPhone,
    'tracking_code': trackingCode,
    'status': status,
    'pickup_address': pickupAddress,
    'delivery_address': deliveryAddress,
    'customer_id': customerId,
    'driver_id': driverId,
    'pickup_lat': pickupLat,
    'pickup_lng': pickupLng,
    'delivery_lat': deliveryLat,
    'delivery_lng': deliveryLng,
    'delivery_fee': deliveryFee,
    'actual_picked_up_at': actualPickedUpAt?.toIso8601String(),
  };
}

class RiskContact {
  const RiskContact({this.name, this.phone, this.email, this.avatarUrl});

  final String? name;
  final String? phone;
  final String? email;
  final String? avatarUrl;

  static RiskContact? fromNestedJson(dynamic value) {
    if (value is! Map) return null;
    return RiskContact(
      name: value['full_name']?.toString(),
      phone: value['phone']?.toString(),
      email: value['email']?.toString(),
      avatarUrl: value['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'full_name': name,
    'phone': phone,
    'email': email,
    'avatar_url': avatarUrl,
  };
}

double? _optionalDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
