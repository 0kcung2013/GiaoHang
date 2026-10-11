import 'order_finance.dart';
import 'order_route_distance.dart';
import 'traffic_demo_clock.dart';
import 'package:giaohang_domain/giaohang_domain.dart'
    show parseCargoWeightKg, DriverMonitoring;

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
    this.pickupArrivedAt,
    this.actualDeliveredAt,
    this.cancelledAt,
    this.assignmentExpiresAt,
    this.assignmentTimedOutAt,
    this.offeredDriverId,
    this.offerExpiresAt,
    this.recipientName,
    this.recipientPhone,
    this.itemName,
    this.itemCategory,
    this.itemDescription,
    this.itemImageUrl,
    this.itemWeightKg,
    required this.deliveryFee,
    required this.serviceType,
    required this.paymentMethod,
    this.paymentMode = OrderPaymentMode.cod,
    this.deliveryFeePayer = DeliveryFeePayer.recipient,
    this.paymentStatus = OrderPaymentStatus.notRequired,
    this.goodsValue = 0,
    this.codCollectionAmount = 0,
    this.platformFeeRateBps = 0,
    this.platformFeeAmount = 0,
    this.driverNetEarning = 0,
    this.driverAdvanceAmount = 0,
    this.receiverCollectionAmount = 0,
    this.paidAt,
    this.statusNote,
    required this.updatedAt,
    this.rejectedBy = const [],
    this.pickupRoadDistanceMeters,
    this.pickupRoadQuotedAt,
    this.pickupRoadOriginLat,
    this.pickupRoadOriginLng,
    this.routeDistance,
    this.driverMonitoring,
    this.trafficDemoKey,
    this.deliveryEtaData,
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
  final DateTime? pickupArrivedAt;
  final DateTime? actualDeliveredAt;
  final DateTime? cancelledAt;
  final DateTime? assignmentExpiresAt;
  final DateTime? assignmentTimedOutAt;
  final String? offeredDriverId;
  final DateTime? offerExpiresAt;
  final String? recipientName;
  final String? recipientPhone;
  final String? itemName;
  final String? itemCategory;
  final String? itemDescription;
  final String? itemImageUrl;
  final double? itemWeightKg;
  final double deliveryFee;
  final String serviceType;
  final String paymentMethod;
  final OrderPaymentMode paymentMode;
  final DeliveryFeePayer deliveryFeePayer;
  final OrderPaymentStatus paymentStatus;
  final int goodsValue;
  final int codCollectionAmount;
  final int platformFeeRateBps;
  final int platformFeeAmount;
  final int driverNetEarning;
  final int driverAdvanceAmount;
  final int receiverCollectionAmount;
  final DateTime? paidAt;
  final String? statusNote;
  final DateTime updatedAt;
  final List<String> rejectedBy;

  // Transient OSRM response fields; never persisted as order columns.
  final double? pickupRoadDistanceMeters;
  final DateTime? pickupRoadQuotedAt;
  final double? pickupRoadOriginLat;
  final double? pickupRoadOriginLng;

  /// Read-only distances from the existing fixed delivery_eta snapshot.
  /// This is not serialized into order writes.
  final OrderRouteDistance? routeDistance;

  /// Trạng thái chỉ đọc; không gửi vào payload tạo/sửa đơn.
  final DriverMonitoring? driverMonitoring;
  final String? trafficDemoKey;

  /// Read-only backend forecast; never included in order submission writes.
  final Map<String, dynamic>? deliveryEtaData;

  /// The backend snapshot opts new, fully paid goods into the deposit policy.
  /// Legacy prepaid orders with zero advance stay on their original contract.
  bool get requiresPaidGoodsDeposit =>
      deliveryFeePayer == DeliveryFeePayer.sender &&
      paymentStatus == OrderPaymentStatus.paid &&
      codCollectionAmount == 0 &&
      goodsValue > 0 &&
      driverAdvanceAmount == goodsValue;

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
      pickupArrivedAt: _parseDateTime(json['pickup_arrived_at']),
      actualDeliveredAt: _parseDateTime(json['actual_delivered_at']),
      cancelledAt: _parseDateTime(json['cancelled_at']),
      assignmentExpiresAt: _parseDateTime(json['assignment_expires_at']),
      assignmentTimedOutAt: _parseDateTime(json['assignment_timed_out_at']),
      offeredDriverId: json['offered_driver_id']?.toString(),
      offerExpiresAt: _parseDateTime(json['offer_expires_at']),
      recipientName: json['recipient_name']?.toString(),
      recipientPhone: json['recipient_phone']?.toString(),
      itemName: json['item_name']?.toString(),
      itemCategory: json['item_category']?.toString(),
      itemDescription: json['item_description']?.toString(),
      itemImageUrl: json['item_image_url']?.toString(),
      itemWeightKg: parseCargoWeightKg(json['item_weight_kg']),
      deliveryFee: _parseDouble(json['delivery_fee']) ?? 0,
      serviceType: json['service_type']?.toString() ?? 'standard',
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      paymentMode: OrderPaymentMode.fromValue(json['payment_mode']),
      deliveryFeePayer: DeliveryFeePayer.fromValue(json['delivery_fee_payer']),
      paymentStatus: OrderPaymentStatus.fromValue(json['payment_status']),
      goodsValue: _parseInt(json['goods_value']) ?? 0,
      codCollectionAmount: _parseInt(json['cod_collection_amount']) ?? 0,
      platformFeeRateBps: _parseInt(json['platform_fee_rate_bps']) ?? 0,
      platformFeeAmount: _parseInt(json['platform_fee_amount']) ?? 0,
      driverNetEarning: _parseInt(json['driver_net_earning']) ?? 0,
      driverAdvanceAmount: _parseInt(json['driver_advance_amount']) ?? 0,
      receiverCollectionAmount:
          _parseInt(json['receiver_collection_amount']) ?? 0,
      paidAt: _parseDateTime(json['paid_at']),
      statusNote: json['status_note']?.toString(),
      updatedAt:
          _parseDateTime(json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      rejectedBy: _parseStringList(json['rejected_by']),
      pickupRoadDistanceMeters: _parseDouble(
        json['pickup_road_distance_meters'],
      ),
      pickupRoadQuotedAt: _parseDateTime(json['pickup_road_quoted_at']),
      pickupRoadOriginLat: _parseDouble(json['pickup_road_origin_lat']),
      pickupRoadOriginLng: _parseDouble(json['pickup_road_origin_lng']),
      routeDistance: OrderRouteDistance.fromFixedEta(
        json['delivery_eta'],
        json['driver_id']?.toString(),
      ),
      driverMonitoring: DriverMonitoring.fromJson(json['driver_monitoring']),
      trafficDemoKey: TrafficDemoClock.validKey(
        json['traffic_demo_key']?.toString(),
      ),
      deliveryEtaData: json['delivery_eta'] is Map
          ? Map<String, dynamic>.from(json['delivery_eta'] as Map)
          : null,
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
      'pickup_arrived_at': pickupArrivedAt?.toIso8601String(),
      'actual_delivered_at': actualDeliveredAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'assignment_expires_at': assignmentExpiresAt?.toIso8601String(),
      'assignment_timed_out_at': assignmentTimedOutAt?.toIso8601String(),
      'offered_driver_id': offeredDriverId,
      'offer_expires_at': offerExpiresAt?.toIso8601String(),
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'item_name': itemName,
      'item_category': itemCategory,
      'item_description': itemDescription,
      'item_image_url': itemImageUrl,
      if (itemWeightKg != null) 'item_weight_kg': itemWeightKg,
      'delivery_fee': deliveryFee,
      'service_type': serviceType,
      'payment_method': paymentMethod,
      'payment_mode': paymentMode.databaseValue,
      'delivery_fee_payer': deliveryFeePayer.databaseValue,
      'payment_status': paymentStatus.databaseValue,
      'goods_value': goodsValue,
      'cod_collection_amount': codCollectionAmount,
      'platform_fee_rate_bps': platformFeeRateBps,
      'platform_fee_amount': platformFeeAmount,
      'driver_net_earning': driverNetEarning,
      'driver_advance_amount': driverAdvanceAmount,
      'receiver_collection_amount': receiverCollectionAmount,
      'paid_at': paidAt?.toIso8601String(),
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

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.round();
    return num.tryParse(value.toString())?.round();
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
    DateTime? pickupArrivedAt,
    DateTime? actualDeliveredAt,
    DateTime? cancelledAt,
    DateTime? assignmentExpiresAt,
    DateTime? assignmentTimedOutAt,
    String? offeredDriverId,
    DateTime? offerExpiresAt,
    String? recipientName,
    String? recipientPhone,
    String? itemName,
    String? itemCategory,
    String? itemDescription,
    String? itemImageUrl,
    double? itemWeightKg,
    double? deliveryFee,
    String? serviceType,
    String? paymentMethod,
    OrderPaymentMode? paymentMode,
    DeliveryFeePayer? deliveryFeePayer,
    OrderPaymentStatus? paymentStatus,
    int? goodsValue,
    int? codCollectionAmount,
    int? platformFeeRateBps,
    int? platformFeeAmount,
    int? driverNetEarning,
    int? driverAdvanceAmount,
    int? receiverCollectionAmount,
    DateTime? paidAt,
    String? statusNote,
    DateTime? updatedAt,
    List<String>? rejectedBy,
    double? pickupRoadDistanceMeters,
    DateTime? pickupRoadQuotedAt,
    double? pickupRoadOriginLat,
    double? pickupRoadOriginLng,
    OrderRouteDistance? routeDistance,
    String? trafficDemoKey,
    Map<String, dynamic>? deliveryEtaData,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      trafficDemoKey: trafficDemoKey ?? this.trafficDemoKey,
      deliveryEtaData: driverId == null || driverId == this.driverId
          ? deliveryEtaData ?? this.deliveryEtaData
          : null,
      status: status ?? this.status,
      driverMonitoring: driverId == null || driverId == this.driverId
          ? driverMonitoring
          : null,
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
      pickupArrivedAt: pickupArrivedAt ?? this.pickupArrivedAt,
      actualDeliveredAt: actualDeliveredAt ?? this.actualDeliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      assignmentExpiresAt: assignmentExpiresAt ?? this.assignmentExpiresAt,
      assignmentTimedOutAt: assignmentTimedOutAt ?? this.assignmentTimedOutAt,
      offeredDriverId: offeredDriverId ?? this.offeredDriverId,
      offerExpiresAt: offerExpiresAt ?? this.offerExpiresAt,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      itemName: itemName ?? this.itemName,
      itemCategory: itemCategory ?? this.itemCategory,
      itemDescription: itemDescription ?? this.itemDescription,
      itemImageUrl: itemImageUrl ?? this.itemImageUrl,
      itemWeightKg: itemWeightKg ?? this.itemWeightKg,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      serviceType: serviceType ?? this.serviceType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentMode: paymentMode ?? this.paymentMode,
      deliveryFeePayer: deliveryFeePayer ?? this.deliveryFeePayer,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      goodsValue: goodsValue ?? this.goodsValue,
      codCollectionAmount: codCollectionAmount ?? this.codCollectionAmount,
      platformFeeRateBps: platformFeeRateBps ?? this.platformFeeRateBps,
      platformFeeAmount: platformFeeAmount ?? this.platformFeeAmount,
      driverNetEarning: driverNetEarning ?? this.driverNetEarning,
      driverAdvanceAmount: driverAdvanceAmount ?? this.driverAdvanceAmount,
      receiverCollectionAmount:
          receiverCollectionAmount ?? this.receiverCollectionAmount,
      paidAt: paidAt ?? this.paidAt,
      statusNote: statusNote ?? this.statusNote,
      updatedAt: updatedAt ?? this.updatedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      pickupRoadDistanceMeters:
          pickupRoadDistanceMeters ?? this.pickupRoadDistanceMeters,
      pickupRoadQuotedAt: pickupRoadQuotedAt ?? this.pickupRoadQuotedAt,
      pickupRoadOriginLat: pickupRoadOriginLat ?? this.pickupRoadOriginLat,
      pickupRoadOriginLng: pickupRoadOriginLng ?? this.pickupRoadOriginLng,
      routeDistance:
          routeDistance ??
          ((driverId == null || driverId == this.driverId) &&
                  (pickupLat == null || pickupLat == this.pickupLat) &&
                  (pickupLng == null || pickupLng == this.pickupLng) &&
                  (deliveryLat == null || deliveryLat == this.deliveryLat) &&
                  (deliveryLng == null || deliveryLng == this.deliveryLng)
              ? this.routeDistance
              : null),
    );
  }

  static const assignmentWindow = Duration(minutes: 15);

  bool get isRiskHeld => status == 'risk_hold';

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

  bool isOfferedToDriverAt(String driverUserId, DateTime now) {
    final normalizedDriverId = driverUserId.trim();
    return normalizedDriverId.isNotEmpty &&
        canWaitForDriver &&
        assignmentTimedOutAt == null &&
        assignmentDeadline.isAfter(now) &&
        offeredDriverId == normalizedDriverId &&
        offerExpiresAt != null &&
        offerExpiresAt!.isAfter(now);
  }

  String effectiveStatusAt(DateTime now) =>
      isAssignmentTimedOutAt(now) ? 'assignment_timeout' : status;
}
