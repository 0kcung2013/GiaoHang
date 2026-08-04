enum RiskSeverity {
  low,
  medium,
  high,
  critical;

  static RiskSeverity fromDatabase(String value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => RiskSeverity.medium,
  );
}

enum RiskCategory {
  deliveryDelay('delivery_delay'),
  suspiciousAddress('suspicious_address'),
  repeatedCancellation('repeated_cancellation'),
  payment('payment'),
  safety('safety'),
  system('system'),
  other('other');

  const RiskCategory(this.databaseValue);
  final String databaseValue;

  static RiskCategory fromDatabase(String value) => values.firstWhere(
    (item) => item.databaseValue == value,
    orElse: () => RiskCategory.other,
  );
}

enum RiskStatus {
  open('open'),
  investigating('investigating'),
  actionRequired('action_required'),
  resolved('resolved'),
  dismissed('dismissed');

  const RiskStatus(this.databaseValue);
  final String databaseValue;

  bool get isClosed => this == resolved || this == dismissed;

  static RiskStatus fromDatabase(String value) => values.firstWhere(
    (item) => item.databaseValue == value,
    orElse: () => RiskStatus.open,
  );
}

class RiskOrderSummary {
  const RiskOrderSummary({
    required this.trackingCode,
    required this.status,
    required this.pickupAddress,
    required this.deliveryAddress,
  });

  final String trackingCode;
  final String status;
  final String pickupAddress;
  final String deliveryAddress;

  factory RiskOrderSummary.fromJson(Map<String, dynamic> json) {
    return RiskOrderSummary(
      trackingCode: json['tracking_code']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      pickupAddress: json['pickup_address']?.toString() ?? '',
      deliveryAddress: json['delivery_address']?.toString() ?? '',
    );
  }
}

class RiskReport {
  const RiskReport({
    required this.id,
    required this.orderId,
    required this.reportedBy,
    required this.assignedTo,
    required this.category,
    required this.severity,
    required this.status,
    required this.title,
    required this.description,
    required this.resolution,
    required this.createdAt,
    required this.updatedAt,
    required this.order,
  });

  final String id;
  final String orderId;
  final String reportedBy;
  final String? assignedTo;
  final RiskCategory category;
  final RiskSeverity severity;
  final RiskStatus status;
  final String title;
  final String description;
  final String? resolution;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RiskOrderSummary order;

  factory RiskReport.fromJson(Map<String, dynamic> json) {
    final orderJson = json['orders'];
    return RiskReport(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      reportedBy: json['reported_by'].toString(),
      assignedTo: json['assigned_to']?.toString(),
      category: RiskCategory.fromDatabase(json['category'].toString()),
      severity: RiskSeverity.fromDatabase(json['severity'].toString()),
      status: RiskStatus.fromDatabase(json['status'].toString()),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      resolution: json['resolution']?.toString(),
      createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'].toString()).toLocal(),
      order: RiskOrderSummary.fromJson(
        orderJson is Map
            ? Map<String, dynamic>.from(orderJson)
            : const <String, dynamic>{},
      ),
    );
  }
}

class RiskReportEvent {
  const RiskReportEvent({
    required this.eventType,
    required this.fromStatus,
    required this.toStatus,
    required this.note,
    required this.createdAt,
  });

  final String eventType;
  final RiskStatus? fromStatus;
  final RiskStatus toStatus;
  final String? note;
  final DateTime createdAt;

  factory RiskReportEvent.fromJson(Map<String, dynamic> json) {
    final fromStatus = json['from_status']?.toString();
    return RiskReportEvent(
      eventType: json['event_type']?.toString() ?? 'updated',
      fromStatus: fromStatus == null
          ? null
          : RiskStatus.fromDatabase(fromStatus),
      toStatus: RiskStatus.fromDatabase(json['to_status'].toString()),
      note: json['note']?.toString(),
      createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
    );
  }
}

class RiskReportDraft {
  const RiskReportDraft({
    required this.trackingCode,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
  });

  final String trackingCode;
  final RiskCategory category;
  final RiskSeverity severity;
  final String title;
  final String description;
}
