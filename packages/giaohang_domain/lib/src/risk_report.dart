enum RiskSeverity {
  low,
  medium,
  high,
  critical;

  static RiskSeverity fromDatabase(String? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => RiskSeverity.medium,
  );
}

enum RiskCategory {
  deliveryDelay('delivery_delay'),
  suspiciousAddress('suspicious_address'),
  contactIssue('contact_issue'),
  cargoIssue('cargo_issue'),
  repeatedCancellation('repeated_cancellation'),
  payment('payment'),
  safety('safety'),
  system('system'),
  other('other');

  const RiskCategory(this.databaseValue);

  final String databaseValue;

  static RiskCategory fromDatabase(String? value) => values.firstWhere(
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

  static RiskStatus fromDatabase(String? value) => values.firstWhere(
    (item) => item.databaseValue == value,
    orElse: () => RiskStatus.open,
  );
}

enum RiskReporterRole {
  customer,
  driver,
  support,
  admin,
  unknown;

  static RiskReporterRole fromDatabase(String? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => RiskReporterRole.unknown,
  );
}

enum RiskInterventionState {
  awaitingTriage('awaiting_triage'),
  heldBeforePickup('held_before_pickup'),
  continueDelivery('continue_delivery'),
  returnRequired('return_required'),
  handoffRequired('handoff_required'),
  released('released');

  const RiskInterventionState(this.databaseValue);

  final String databaseValue;

  static RiskInterventionState fromDatabase(String? value) => values.firstWhere(
    (item) => item.databaseValue == value,
    orElse: () => RiskInterventionState.awaitingTriage,
  );
}

enum RiskEvidenceType {
  photo,
  location;

  static RiskEvidenceType fromDatabase(String? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => RiskEvidenceType.photo,
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
    this.reporterRole = RiskReporterRole.unknown,
    this.reporterName,
    this.triageDueAt,
    this.escalatedAt,
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
  final RiskReporterRole reporterRole;
  final String? reporterName;
  final DateTime? triageDueAt;
  final DateTime? escalatedAt;

  bool get triageOverdue =>
      triageDueAt != null && escalatedAt != null && !status.isClosed;

  factory RiskReport.fromJson(Map<String, dynamic> json) {
    final orderJson = _nestedMap(json['orders']);
    final reporterJson = _nestedMap(json['reporter']);
    return RiskReport(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      reportedBy: json['reported_by'].toString(),
      assignedTo: json['assigned_to']?.toString(),
      category: RiskCategory.fromDatabase(json['category']?.toString()),
      severity: RiskSeverity.fromDatabase(json['severity']?.toString()),
      status: RiskStatus.fromDatabase(json['status']?.toString()),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      resolution: json['resolution']?.toString(),
      createdAt: _requiredLocalDate(json['created_at']),
      updatedAt: _requiredLocalDate(json['updated_at']),
      order: RiskOrderSummary.fromJson(orderJson),
      reporterRole: RiskReporterRole.fromDatabase(
        json['reporter_role_snapshot']?.toString() ??
            reporterJson['role']?.toString(),
      ),
      reporterName: reporterJson['full_name']?.toString(),
      triageDueAt: _optionalLocalDate(json['triage_due_at']),
      escalatedAt: _optionalLocalDate(json['escalated_at']),
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
      toStatus: RiskStatus.fromDatabase(json['to_status']?.toString()),
      note: json['note']?.toString(),
      createdAt: _requiredLocalDate(json['created_at']),
    );
  }
}

class RiskReportAttachment {
  const RiskReportAttachment({
    required this.id,
    required this.riskReportId,
    required this.orderId,
    required this.evidenceType,
    required this.storagePath,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    required this.createdAt,
  });

  final String id;
  final String riskReportId;
  final String orderId;
  final RiskEvidenceType evidenceType;
  final String? storagePath;
  final double? latitude;
  final double? longitude;
  final DateTime? capturedAt;
  final DateTime createdAt;

  factory RiskReportAttachment.fromJson(Map<String, dynamic> json) {
    return RiskReportAttachment(
      id: json['id'].toString(),
      riskReportId: json['risk_report_id'].toString(),
      orderId: json['order_id'].toString(),
      evidenceType: RiskEvidenceType.fromDatabase(
        json['evidence_type']?.toString(),
      ),
      storagePath: json['storage_path']?.toString(),
      latitude: _optionalDouble(json['latitude']),
      longitude: _optionalDouble(json['longitude']),
      capturedAt: _optionalLocalDate(json['captured_at']),
      createdAt: _requiredLocalDate(json['created_at']),
    );
  }
}

class RiskIntervention {
  const RiskIntervention({
    required this.riskReportId,
    required this.orderId,
    required this.state,
    required this.driverId,
    required this.decisionDueAt,
    required this.instruction,
    required this.driverReleasedAt,
  });

  final String riskReportId;
  final String orderId;
  final RiskInterventionState state;
  final String? driverId;
  final DateTime decisionDueAt;
  final String? instruction;
  final DateTime? driverReleasedAt;

  factory RiskIntervention.fromJson(Map<String, dynamic> json) {
    return RiskIntervention(
      riskReportId: json['risk_report_id'].toString(),
      orderId: json['order_id'].toString(),
      state: RiskInterventionState.fromDatabase(json['state']?.toString()),
      driverId: json['driver_id']?.toString(),
      decisionDueAt: _requiredLocalDate(json['decision_due_at']),
      instruction: json['instruction']?.toString(),
      driverReleasedAt: _optionalLocalDate(json['driver_released_at']),
    );
  }
}

class RiskReportSubmission {
  const RiskReportSubmission({
    required this.reportId,
    required this.orderId,
    required this.category,
    required this.description,
    required this.photoPaths,
    required this.messageIds,
    this.latitude,
    this.longitude,
    this.locationCapturedAt,
  });

  final String reportId;
  final String orderId;
  final RiskCategory category;
  final String description;
  final List<String> photoPaths;
  final List<String> messageIds;
  final double? latitude;
  final double? longitude;
  final DateTime? locationCapturedAt;

  Map<String, dynamic> toRpcJson() => {
    'p_report_id': reportId,
    'p_order_id': orderId,
    'p_category': category.databaseValue,
    'p_description': description.trim(),
    'p_photo_paths': photoPaths,
    'p_latitude': latitude,
    'p_longitude': longitude,
    'p_location_captured_at': locationCapturedAt?.toUtc().toIso8601String(),
    'p_message_ids': messageIds,
  };
}

class RiskReportSubmissionResult {
  const RiskReportSubmissionResult({
    required this.reportId,
    required this.status,
  });

  final String reportId;
  final RiskStatus status;

  factory RiskReportSubmissionResult.fromJson(Map<String, dynamic> json) {
    return RiskReportSubmissionResult(
      reportId: json['report_id'].toString(),
      status: RiskStatus.fromDatabase(json['status']?.toString()),
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

Map<String, dynamic> _nestedMap(dynamic value) {
  return value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};
}

DateTime _requiredLocalDate(dynamic value) {
  return DateTime.parse(value.toString()).toLocal();
}

DateTime? _optionalLocalDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

double? _optionalDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
