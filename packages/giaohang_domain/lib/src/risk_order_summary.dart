import 'cargo_weight.dart';
import 'driver_monitoring.dart';
import 'business_settings.dart';

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
    this.id = '',
    this.itemName,
    this.itemCategory,
    this.itemDescription,
    this.itemImageUrl,
    this.itemWeightKg,
    this.note,
    this.statusNote,
    this.serviceType,
    this.paymentMethod,
    this.deliveryFeePayer,
    this.paymentStatus,
    this.totalPrice,
    this.goodsValue,
    this.codCollectionAmount,
    this.driverAdvanceAmount,
    this.receiverCollectionAmount,
    this.driverNetEarning,
    this.createdAt,
    this.updatedAt,
    this.estimatedPickupAt,
    this.estimatedDeliveryAt,
    this.actualDeliveredAt,
    this.cancelledAt,
    this.deliveryEta,
    this.driverMonitoring,
    this.businessPolicy,
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
  final String id;
  final String? itemName;
  final String? itemCategory;
  final String? itemDescription;
  final String? itemImageUrl;
  final double? itemWeightKg;
  final String? note;
  final String? statusNote;
  final String? serviceType;
  final String? paymentMethod;
  final String? deliveryFeePayer;
  final String? paymentStatus;
  final int? totalPrice;
  final int? goodsValue;
  final int? codCollectionAmount;
  final int? driverAdvanceAmount;
  final int? receiverCollectionAmount;
  final int? driverNetEarning;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? estimatedPickupAt;
  final DateTime? estimatedDeliveryAt;
  final DateTime? actualDeliveredAt;
  final DateTime? cancelledAt;
  final Map<String, dynamic>? deliveryEta;
  final DriverMonitoring? driverMonitoring;
  final BusinessSettings? businessPolicy;
  int get returnFee =>
      (businessPolicy ?? BusinessSettings()).returnFee(deliveryFee).round();

  DateTime? get predictedDeliveryAt =>
      driverId != null && deliveryEta?['driver_id'] == driverId
      ? _date(deliveryEta?['predicted_at'])
      : null;

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
      businessPolicy: json['business_policy'] is Map
          ? BusinessSettings.fromJson(
              Map<String, dynamic>.from(json['business_policy'] as Map),
            )
          : null,
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
      deliveryFee: _integer(json['delivery_fee']) ?? 0,
      actualPickedUpAt: DateTime.tryParse(
        json['actual_picked_up_at']?.toString() ?? '',
      ),
      id: json['id']?.toString() ?? '',
      itemName: json['item_name']?.toString(),
      itemCategory: json['item_category']?.toString(),
      itemDescription: json['item_description']?.toString(),
      itemImageUrl: json['item_image_url']?.toString(),
      itemWeightKg: parseCargoWeightKg(json['item_weight_kg']),
      note: json['note']?.toString(),
      statusNote: json['status_note']?.toString(),
      serviceType: json['service_type']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      deliveryFeePayer: json['delivery_fee_payer']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      totalPrice: _integer(json['total_price']),
      goodsValue: _integer(json['goods_value']),
      codCollectionAmount: _integer(json['cod_collection_amount']),
      driverAdvanceAmount: _integer(json['driver_advance_amount']),
      receiverCollectionAmount: _integer(json['receiver_collection_amount']),
      driverNetEarning: _integer(json['driver_net_earning']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      estimatedPickupAt: _date(json['estimated_pickup_at']),
      estimatedDeliveryAt: _date(json['estimated_delivery_at']),
      actualDeliveredAt: _date(json['actual_delivered_at']),
      cancelledAt: _date(json['cancelled_at']),
      deliveryEta: json['delivery_eta'] is Map
          ? Map<String, dynamic>.from(json['delivery_eta'] as Map)
          : null,
      driverMonitoring: DriverMonitoring.fromJson(json['driver_monitoring']),
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
    'id': id,
    'item_name': itemName,
    'item_category': itemCategory,
    'item_description': itemDescription,
    'item_image_url': itemImageUrl,
    'item_weight_kg': itemWeightKg,
    'note': note,
    'status_note': statusNote,
    'service_type': serviceType,
    'payment_method': paymentMethod,
    'delivery_fee_payer': deliveryFeePayer,
    'payment_status': paymentStatus,
    'total_price': totalPrice,
    'goods_value': goodsValue,
    'cod_collection_amount': codCollectionAmount,
    'driver_advance_amount': driverAdvanceAmount,
    'receiver_collection_amount': receiverCollectionAmount,
    'driver_net_earning': driverNetEarning,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'estimated_pickup_at': estimatedPickupAt?.toIso8601String(),
    'estimated_delivery_at': estimatedDeliveryAt?.toIso8601String(),
    'actual_delivered_at': actualDeliveredAt?.toIso8601String(),
    'cancelled_at': cancelledAt?.toIso8601String(),
    'delivery_eta': deliveryEta,
    'driver_monitoring': driverMonitoring?.toJson(),
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

int? _integer(Object? value) => value is num
    ? value.round()
    : num.tryParse(value?.toString() ?? '')?.round();

DateTime? _date(Object? value) => DateTime.tryParse(value?.toString() ?? '');
