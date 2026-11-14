import 'vietnam_time.dart';

/// A server snapshot. Order totals and dated cash movements are deliberately
/// separate: a COD credit can precede delivery and is not a tax revenue figure.
class BusinessReport {
  BusinessReport({
    required this.customerId,
    required this.name,
    required this.address,
    this.taxCode,
    required this.start,
    required this.end,
    required this.generatedAt,
    required List<BusinessReportOrder> orders,
    required List<BusinessReportMovement> movements,
  }) : orders = List.unmodifiable(orders),
       movements = List.unmodifiable(movements);
  final String customerId, name, address;
  final String? taxCode;
  final DateTime start, end, generatedAt;
  final List<BusinessReportOrder> orders;
  final List<BusinessReportMovement> movements;

  factory BusinessReport.fromJson(Map<String, dynamic> json) {
    final profile = Map<String, dynamic>.from(json['profile'] as Map);
    return BusinessReport(
      customerId: profile['id'] as String,
      name: profile['business_name'] as String,
      address: profile['business_address'] as String,
      taxCode: profile['business_tax_code'] as String?,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      generatedAt: DateTime.parse(json['generated_at'] as String),
      orders: (json['orders'] as List)
          .map(
            (r) => BusinessReportOrder.fromJson(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList(),
      movements: (json['movements'] as List)
          .map(
            (r) => BusinessReportMovement.fromJson(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList(),
    );
  }

  int get deliveredCod => orders
      .where((o) => o.status == 'delivered')
      .fold(0, (sum, o) => sum + o.cod);
  int get walletCodCredits => movements
      .where((m) => m.kind == 'delivery_credit')
      .fold(0, (sum, m) => sum + m.amount);
  int get walletRefunds => movements
      .where((m) => m.kind == 'delivery_fee_refund')
      .fold(0, (sum, m) => sum + m.amount);
  int get senderCharges => orders.fold(0, (sum, o) => sum + o.senderCharge);
  int get recipientCharges =>
      orders.fold(0, (sum, o) => sum + o.recipientCharge);

  Map<String, dynamic> toJson() => {
    'profile': {
      'id': customerId,
      'business_name': name,
      'business_address': address,
      'business_tax_code': taxCode,
    },
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'generated_at': generatedAt.toUtc().toIso8601String(),
    'orders': orders.map((o) => o.toJson()).toList(),
    'movements': movements.map((m) => m.toJson()).toList(),
  };
}

class BusinessReportOrder {
  const BusinessReportOrder({
    required this.id,
    required this.code,
    required this.status,
    required this.eventAt,
    required this.cod,
    required this.deliveryFee,
    required this.platformFee,
    required this.payer,
    required this.paymentStatus,
    required this.returnCharge,
    this.returnFeeStatus,
  });
  final String id, code, status, payer, paymentStatus;
  final String? returnFeeStatus;
  final DateTime eventAt;
  final int cod, deliveryFee, platformFee, returnCharge;

  // Costs refer to completed service, not the date cash was paid. Cancellations
  // carry no service expense. Returned orders have the platform fee waived/refunded.
  int get serviceCharge => switch (status) {
    'delivered' => deliveryFee + platformFee,
    'returned' => deliveryFee,
    _ => 0,
  };
  int get settledReturnCharge =>
      status == 'returned' && returnFeeStatus == 'settled' ? returnCharge : 0;
  int get senderCharge =>
      (payer == 'sender' ? serviceCharge : 0) + settledReturnCharge;
  int get recipientCharge =>
      status == 'delivered' && payer == 'recipient' ? serviceCharge : 0;

  factory BusinessReportOrder.fromJson(Map<String, dynamic> j) =>
      BusinessReportOrder(
        id: j['id'] as String,
        code: j['tracking_code'] as String? ?? j['id'] as String,
        status: j['status'] as String,
        payer: j['delivery_fee_payer'] as String,
        paymentStatus: j['payment_status'] as String,
        eventAt: DateTime.parse(j['event_at'] as String),
        cod: _amount(j['cod_collection_amount']),
        deliveryFee: _amount(j['delivery_fee']),
        platformFee: _amount(j['customer_platform_fee_amount']),
        returnCharge: _amount(j['return_charge']),
        returnFeeStatus: j['return_fee_status'] as String?,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'tracking_code': code,
    'status': status,
    'delivery_fee_payer': payer,
    'payment_status': paymentStatus,
    'event_at': eventAt.toUtc().toIso8601String(),
    'cod_collection_amount': cod,
    'delivery_fee': deliveryFee,
    'customer_platform_fee_amount': platformFee,
    'return_charge': returnCharge,
    'return_fee_status': returnFeeStatus,
  };
}

class BusinessReportMovement {
  const BusinessReportMovement({
    required this.id,
    required this.kind,
    required this.amount,
    required this.eventAt,
    this.orderId,
    this.code,
    this.paymentState,
  });
  final String id, kind;
  final String? orderId, code, paymentState;
  final int amount;
  final DateTime eventAt;
  factory BusinessReportMovement.fromJson(Map<String, dynamic> j) =>
      BusinessReportMovement(
        id: j['id'] as String,
        kind: j['kind'] as String,
        amount: _amount(j['amount']),
        eventAt: DateTime.parse(j['event_at'] as String),
        orderId: j['order_id'] as String?,
        code: j['tracking_code'] as String?,
        paymentState: j['payment_state'] as String?,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'amount': amount,
    'event_at': eventAt.toUtc().toIso8601String(),
    'order_id': orderId,
    'tracking_code': code,
    'payment_state': paymentState,
  };
}

/// Input fields are Vietnam calendar dates, independent of the device timezone.
DateTime businessReportBoundary(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).subtract(VietnamTime.utcOffset);

int _amount(Object? value) =>
    value is num ? value.round() : int.parse(value.toString());
