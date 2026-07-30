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
    this.assignmentExpiresAt,
    this.assignmentTimedOutAt,
    this.recipientName,
    this.recipientPhone,
    this.itemName,
    this.itemCategory,
    this.itemDescription,
    this.itemImageUrl,
    required this.deliveryFee,
    required this.serviceType,
    required this.paymentMethod,
    this.statusNote,
    required this.updatedAt,
    this.rejectedBy = const [],
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
  final DateTime? assignmentExpiresAt;
  final DateTime? assignmentTimedOutAt;
  final String? recipientName;
  final String? recipientPhone;
  final String? itemName;
  final String? itemCategory;
  final String? itemDescription;
  final String? itemImageUrl;
  final double deliveryFee;
  final String serviceType;
  final String paymentMethod;
  final String? statusNote;
  final DateTime updatedAt;
  final List<String> rejectedBy;

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
      assignmentExpiresAt: _parseDateTime(json['assignment_expires_at']),
      assignmentTimedOutAt: _parseDateTime(json['assignment_timed_out_at']),
      recipientName: json['recipient_name']?.toString(),
      recipientPhone: json['recipient_phone']?.toString(),
      itemName: json['item_name']?.toString(),
      itemCategory: json['item_category']?.toString(),
      itemDescription: json['item_description']?.toString(),
      itemImageUrl: json['item_image_url']?.toString(),
      deliveryFee: _parseDouble(json['delivery_fee']) ?? 0,
      serviceType: json['service_type']?.toString() ?? 'standard',
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      statusNote: json['status_note']?.toString(),
      updatedAt:
          _parseDateTime(json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      rejectedBy: _parseStringList(json['rejected_by']),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    // jsonb đôi khi về string "[]" / JSON encoded
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == '[]') return const [];
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        final inner = trimmed.substring(1, trimmed.length - 1).trim();
        if (inner.isEmpty) return const [];
        return inner
            .split(',')
            .map((e) => e.trim().replaceAll('"', '').replaceAll("'", ''))
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return const [];
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
      'assignment_expires_at': assignmentExpiresAt?.toIso8601String(),
      'assignment_timed_out_at': assignmentTimedOutAt?.toIso8601String(),
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'item_name': itemName,
      'item_category': itemCategory,
      'item_description': itemDescription,
      'item_image_url': itemImageUrl,
      'delivery_fee': deliveryFee,
      'service_type': serviceType,
      'payment_method': paymentMethod,
      'status_note': statusNote,
      'updated_at': updatedAt.toIso8601String(),
      'rejected_by': rejectedBy,
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

  OrderModel copyWith({
    String? id,
    String? customerId,
    String? driverId,
    String? status,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    double? totalPrice,
    String? note,
    DateTime? createdAt,
    String? trackingCode,
    DateTime? estimatedPickupAt,
    DateTime? estimatedDeliveryAt,
    DateTime? actualPickedUpAt,
    DateTime? actualDeliveredAt,
    DateTime? cancelledAt,
    DateTime? assignmentExpiresAt,
    DateTime? assignmentTimedOutAt,
    String? recipientName,
    String? recipientPhone,
    String? itemName,
    String? itemCategory,
    String? itemDescription,
    String? itemImageUrl,
    double? deliveryFee,
    String? serviceType,
    String? paymentMethod,
    String? statusNote,
    DateTime? updatedAt,
    List<String>? rejectedBy,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLat: deliveryLat ?? this.deliveryLat,
      deliveryLng: deliveryLng ?? this.deliveryLng,
      totalPrice: totalPrice ?? this.totalPrice,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      trackingCode: trackingCode ?? this.trackingCode,
      estimatedPickupAt: estimatedPickupAt ?? this.estimatedPickupAt,
      estimatedDeliveryAt: estimatedDeliveryAt ?? this.estimatedDeliveryAt,
      actualPickedUpAt: actualPickedUpAt ?? this.actualPickedUpAt,
      actualDeliveredAt: actualDeliveredAt ?? this.actualDeliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      assignmentExpiresAt: assignmentExpiresAt ?? this.assignmentExpiresAt,
      assignmentTimedOutAt: assignmentTimedOutAt ?? this.assignmentTimedOutAt,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      itemName: itemName ?? this.itemName,
      itemCategory: itemCategory ?? this.itemCategory,
      itemDescription: itemDescription ?? this.itemDescription,
      itemImageUrl: itemImageUrl ?? this.itemImageUrl,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      serviceType: serviceType ?? this.serviceType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      statusNote: statusNote ?? this.statusNote,
      updatedAt: updatedAt ?? this.updatedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
    );
  }

  static const assignmentWindow = Duration(minutes: 15);

  DateTime get assignmentDeadline =>
      assignmentExpiresAt ?? createdAt.add(assignmentWindow);

  bool get canWaitForDriver =>
      driverId?.trim().isNotEmpty != true &&
      (status == 'pending' || status == 'confirmed');

  bool isAwaitingDriverAt(DateTime now) =>
      canWaitForDriver &&
      assignmentTimedOutAt == null &&
      assignmentDeadline.isAfter(now);

  bool isAssignmentTimedOutAt(DateTime now) =>
      canWaitForDriver &&
      (assignmentTimedOutAt != null || !assignmentDeadline.isAfter(now));

  String effectiveStatusAt(DateTime now) =>
      isAssignmentTimedOutAt(now) ? 'assignment_timeout' : status;
}
