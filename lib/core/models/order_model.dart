class OrderModel {
  const OrderModel({
    required this.id,
    required this.customerId,
    this.driverId,
    required this.status,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    this.totalPrice,
    this.note,
    required this.createdAt,
    required this.trackingCode,
    this.estimatedPickupAt,
    this.estimatedDeliveryAt,
    this.actualPickedUpAt,
    this.actualDeliveredAt,
    this.cancelledAt,
    this.recipientName,
    this.recipientPhone,
    required this.deliveryFee,
    required this.serviceType,
    required this.paymentMethod,
    this.statusNote,
    required this.updatedAt,
  });

  final String id;
  final String customerId;
  final String? driverId;
  final String status;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  final double? totalPrice;
  final String? note;
  final DateTime createdAt;
  final String trackingCode;
  final DateTime? estimatedPickupAt;
  final DateTime? estimatedDeliveryAt;
  final DateTime? actualPickedUpAt;
  final DateTime? actualDeliveredAt;
  final DateTime? cancelledAt;
  final String? recipientName;
  final String? recipientPhone;
  final double deliveryFee;
  final String serviceType;
  final String paymentMethod;
  final String? statusNote;
  final DateTime updatedAt;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      driverId: json['driver_id']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      pickupAddress: json['pickup_address']?.toString() ?? '',
      pickupLat: _parseDouble(json['pickup_lat']) ?? 0,
      pickupLng: _parseDouble(json['pickup_lng']) ?? 0,
      deliveryAddress: json['delivery_address']?.toString() ?? '',
      deliveryLat: _parseDouble(json['delivery_lat']) ?? 0,
      deliveryLng: _parseDouble(json['delivery_lng']) ?? 0,
      totalPrice: _parseDouble(json['total_price']),
      note: json['note']?.toString(),
      createdAt:
          _parseDateTime(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      trackingCode: json['tracking_code']?.toString() ?? '',
      estimatedPickupAt: _parseDateTime(json['estimated_pickup_at']),
      estimatedDeliveryAt: _parseDateTime(json['estimated_delivery_at']),
      actualPickedUpAt: _parseDateTime(json['actual_picked_up_at']),
      actualDeliveredAt: _parseDateTime(json['actual_delivered_at']),
      cancelledAt: _parseDateTime(json['cancelled_at']),
      recipientName: json['recipient_name']?.toString(),
      recipientPhone: json['recipient_phone']?.toString(),
      deliveryFee: _parseDouble(json['delivery_fee']) ?? 0,
      serviceType: json['service_type']?.toString() ?? 'standard',
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      statusNote: json['status_note']?.toString(),
      updatedAt:
          _parseDateTime(json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'driver_id': driverId,
      'status': status,
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'delivery_address': deliveryAddress,
      'delivery_lat': deliveryLat,
      'delivery_lng': deliveryLng,
      'total_price': totalPrice,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'tracking_code': trackingCode,
      'estimated_pickup_at': estimatedPickupAt?.toIso8601String(),
      'estimated_delivery_at': estimatedDeliveryAt?.toIso8601String(),
      'actual_picked_up_at': actualPickedUpAt?.toIso8601String(),
      'actual_delivered_at': actualDeliveredAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'delivery_fee': deliveryFee,
      'service_type': serviceType,
      'payment_method': paymentMethod,
      'status_note': statusNote,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}