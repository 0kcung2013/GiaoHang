enum OrderReturnStatus {
  approved,
  returning,
  returned;

  static OrderReturnStatus fromDatabase(Object? value) => values.firstWhere(
    (status) => status.name == value?.toString(),
    orElse: () => OrderReturnStatus.approved,
  );
}

enum ReturnDestinationType {
  sender,
  processingCenter;

  String get databaseValue => switch (this) {
    ReturnDestinationType.sender => 'sender',
    ReturnDestinationType.processingCenter => 'processing_center',
  };

  static ReturnDestinationType fromDatabase(Object? value) =>
      value?.toString() == 'processing_center'
      ? ReturnDestinationType.processingCenter
      : ReturnDestinationType.sender;
}

enum ReturnFeePayer {
  customer,
  platform,
  pendingSupport;

  String get databaseValue => switch (this) {
    ReturnFeePayer.customer => 'customer',
    ReturnFeePayer.platform => 'platform',
    ReturnFeePayer.pendingSupport => 'pending_support',
  };

  static ReturnFeePayer fromDatabase(Object? value) =>
      switch (value?.toString()) {
        'platform' => ReturnFeePayer.platform,
        'pending_support' => ReturnFeePayer.pendingSupport,
        _ => ReturnFeePayer.customer,
      };
}

enum ReturnFeeStatus {
  quoted,
  approved,
  settled,
  waived;

  static ReturnFeeStatus fromDatabase(Object? value) => values.firstWhere(
    (status) => status.name == value?.toString(),
    orElse: () => ReturnFeeStatus.approved,
  );
}

enum ReturnQuoteSource {
  osrm,
  fallback;

  static ReturnQuoteSource fromDatabase(Object? value) =>
      value?.toString() == 'osrm'
      ? ReturnQuoteSource.osrm
      : ReturnQuoteSource.fallback;
}

abstract final class OrderReturnPricingPolicy {
  static const int returnFeeRateBps = 5000;

  static int calculateReturnFee(int deliveryFee) {
    if (deliveryFee <= 0) return 0;
    return (deliveryFee * returnFeeRateBps + 5000) ~/ 10000;
  }

  static int calculateTotalDriverEarning(int deliveryFee) =>
      deliveryFee + calculateReturnFee(deliveryFee);
}

class OrderReturn {
  const OrderReturn({
    required this.id,
    required this.orderId,
    required this.riskReportId,
    required this.driverId,
    required this.status,
    required this.destinationType,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.routeOriginLat,
    required this.routeOriginLng,
    required this.routeDistanceMeters,
    required this.routeDurationSeconds,
    required this.quoteSource,
    required this.reasonCode,
    required this.feePayer,
    required this.customerReturnCharge,
    required this.driverReturnEarning,
    required this.feeStatus,
    required this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.instruction,
    this.receiverName,
    this.proofStoragePath,
    this.startedAt,
    this.arrivedAt,
    this.returnedAt,
  });

  final String id;
  final String orderId;
  final String riskReportId;
  final String driverId;
  final OrderReturnStatus status;
  final ReturnDestinationType destinationType;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final double routeOriginLat;
  final double routeOriginLng;
  final int routeDistanceMeters;
  final int routeDurationSeconds;
  final ReturnQuoteSource quoteSource;
  final String reasonCode;
  final ReturnFeePayer feePayer;
  final int customerReturnCharge;
  final int driverReturnEarning;
  final ReturnFeeStatus feeStatus;
  final String? instruction;
  final String? receiverName;
  final String? proofStoragePath;
  final DateTime approvedAt;
  final DateTime? startedAt;
  final DateTime? arrivedAt;
  final DateTime? returnedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status != OrderReturnStatus.returned;
  bool get canStart => status == OrderReturnStatus.approved;
  bool get canComplete => status == OrderReturnStatus.returning;

  factory OrderReturn.fromJson(Map<String, dynamic> json) {
    return OrderReturn(
      id: _string(json['id']),
      orderId: _string(json['order_id']),
      riskReportId: _string(json['risk_report_id']),
      driverId: _string(json['driver_id']),
      status: OrderReturnStatus.fromDatabase(json['status']),
      destinationType: ReturnDestinationType.fromDatabase(
        json['destination_type'],
      ),
      destinationAddress: _string(json['destination_address']),
      destinationLat: _double(json['destination_lat']),
      destinationLng: _double(json['destination_lng']),
      routeOriginLat: _double(json['route_origin_lat']),
      routeOriginLng: _double(json['route_origin_lng']),
      routeDistanceMeters: _int(json['route_distance_m']),
      routeDurationSeconds: _int(json['route_duration_s']),
      quoteSource: ReturnQuoteSource.fromDatabase(json['quote_source']),
      reasonCode: _string(json['reason_code']),
      feePayer: ReturnFeePayer.fromDatabase(json['fee_payer']),
      customerReturnCharge: _int(json['customer_return_charge']),
      driverReturnEarning: _int(json['driver_return_earning']),
      feeStatus: ReturnFeeStatus.fromDatabase(json['fee_status']),
      instruction: json['instruction']?.toString(),
      receiverName: json['receiver_name']?.toString(),
      proofStoragePath: json['proof_storage_path']?.toString(),
      approvedAt: _date(json['approved_at']),
      startedAt: _optionalDate(json['started_at']),
      arrivedAt: _optionalDate(json['arrived_at']),
      returnedAt: _optionalDate(json['returned_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'risk_report_id': riskReportId,
    'driver_id': driverId,
    'status': status.name,
    'destination_type': destinationType.databaseValue,
    'destination_address': destinationAddress,
    'destination_lat': destinationLat,
    'destination_lng': destinationLng,
    'route_origin_lat': routeOriginLat,
    'route_origin_lng': routeOriginLng,
    'route_distance_m': routeDistanceMeters,
    'route_duration_s': routeDurationSeconds,
    'quote_source': quoteSource.name,
    'reason_code': reasonCode,
    'fee_payer': feePayer.databaseValue,
    'customer_return_charge': customerReturnCharge,
    'driver_return_earning': driverReturnEarning,
    'fee_status': feeStatus.name,
    'instruction': instruction,
    'receiver_name': receiverName,
    'proof_storage_path': proofStoragePath,
    'approved_at': approvedAt.toUtc().toIso8601String(),
    'started_at': startedAt?.toUtc().toIso8601String(),
    'arrived_at': arrivedAt?.toUtc().toIso8601String(),
    'returned_at': returnedAt?.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

class ReturnApprovalDraft {
  const ReturnApprovalDraft({
    required this.reportId,
    required this.reasonCode,
    required this.destinationType,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.routeOriginLat,
    required this.routeOriginLng,
    required this.routeDistanceMeters,
    required this.routeDurationSeconds,
    required this.quoteSource,
    required this.feePayer,
    required this.customerReturnCharge,
    required this.driverReturnEarning,
    this.instruction,
  });

  final String reportId;
  final String reasonCode;
  final ReturnDestinationType destinationType;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final double routeOriginLat;
  final double routeOriginLng;
  final int routeDistanceMeters;
  final int routeDurationSeconds;
  final ReturnQuoteSource quoteSource;
  final ReturnFeePayer feePayer;
  final int customerReturnCharge;
  final int driverReturnEarning;
  final String? instruction;

  Map<String, dynamic> toRpcParams() => {
    'p_report_id': reportId,
    'p_reason_code': reasonCode,
    'p_destination_type': destinationType.databaseValue,
    'p_destination_address': destinationAddress,
    'p_destination_lat': destinationLat,
    'p_destination_lng': destinationLng,
    'p_route_origin_lat': routeOriginLat,
    'p_route_origin_lng': routeOriginLng,
    'p_route_distance_m': routeDistanceMeters,
    'p_route_duration_s': routeDurationSeconds,
    'p_quote_source': quoteSource.name,
    'p_fee_payer': feePayer.databaseValue,
    'p_customer_return_charge': customerReturnCharge,
    'p_driver_return_earning': driverReturnEarning,
    'p_instruction': instruction,
  };
}

String _string(Object? value) => value?.toString() ?? '';
double _double(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
int _int(Object? value) =>
    value is num ? value.round() : int.tryParse(value?.toString() ?? '') ?? 0;
DateTime _date(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
    DateTime.fromMillisecondsSinceEpoch(0);
DateTime? _optionalDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
