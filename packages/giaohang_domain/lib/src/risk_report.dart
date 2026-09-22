import 'risk_order_summary.dart';
import 'risk_report_types.dart';

export 'risk_order_summary.dart';
export 'risk_report_types.dart';

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
    this.scope = RiskScope.order,
    this.component,
    this.reporterRole = RiskReporterRole.unknown,
    this.reporterName,
    this.reporterAvatarUrl,
    this.reporterPhone,
    this.reporterEmail,
    this.assignedToName,
    this.triageDueAt,
    this.firstResponseAt,
    this.responseDueAt,
    this.escalatedAt,
    this.interventionState,
  });

  final String id;
  final String orderId;
  final String reportedBy;
  final String? assignedTo;
  final RiskScope scope;
  final String? component;
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
  final String? reporterAvatarUrl;
  final String? reporterPhone;
  final String? reporterEmail;
  final String? assignedToName;
  final DateTime? triageDueAt;
  final DateTime? firstResponseAt;
  final DateTime? responseDueAt;
  final DateTime? escalatedAt;
  final RiskInterventionState? interventionState;

  bool get isSystemIncident => scope == RiskScope.system;

  bool get responseOverdue =>
      responseDueAt != null &&
      DateTime.now().isAfter(responseDueAt!) &&
      firstResponseAt == null &&
      !status.isClosed;

  bool get triageOverdue =>
      triageDueAt != null &&
      escalatedAt != null &&
      interventionState == RiskInterventionState.awaitingTriage &&
      !status.isClosed;

  factory RiskReport.fromJson(Map<String, dynamic> json) {
    final orderJson = _nestedMap(json['orders']);
    final reporterJson = _nestedMap(json['reporter']);
    final assigneeJson = _nestedMap(json['assignee']);
    return RiskReport(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      reportedBy: json['reported_by']?.toString() ?? '',
      assignedTo: json['assigned_to']?.toString(),
      scope: RiskScope.fromDatabase(json['scope']?.toString()),
      component: json['component']?.toString(),
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
      reporterName:
          reporterJson['full_name']?.toString() ??
          json['reporter_name']?.toString(),
      reporterAvatarUrl:
          reporterJson['avatar_url']?.toString() ??
          json['reporter_avatar_url']?.toString(),
      reporterPhone:
          reporterJson['phone']?.toString() ??
          json['reporter_phone']?.toString(),
      reporterEmail:
          reporterJson['email']?.toString() ??
          json['reporter_email']?.toString(),
      assignedToName:
          assigneeJson['full_name']?.toString() ??
          json['assigned_to_name']?.toString(),
      triageDueAt: _optionalLocalDate(json['triage_due_at']),
      firstResponseAt: _optionalLocalDate(json['first_response_at']),
      responseDueAt: _optionalLocalDate(json['response_due_at']),
      escalatedAt: _optionalLocalDate(json['escalated_at']),
      interventionState: json['intervention_state'] == null
          ? null
          : RiskInterventionState.fromDatabase(
              json['intervention_state']?.toString(),
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId.isEmpty ? null : orderId,
    'reported_by': reportedBy,
    'assigned_to': assignedTo,
    'scope': scope.databaseValue,
    'component': component,
    'category': category.databaseValue,
    'severity': severity.name,
    'status': status.databaseValue,
    'title': title,
    'description': description,
    'resolution': resolution,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'orders': order.toJson(),
    'reporter_role_snapshot': reporterRole.name,
    'reporter_name': reporterName,
    'reporter_avatar_url': reporterAvatarUrl,
    'reporter_phone': reporterPhone,
    'reporter_email': reporterEmail,
    'assigned_to_name': assignedToName,
    'triage_due_at': triageDueAt?.toUtc().toIso8601String(),
    'first_response_at': firstResponseAt?.toUtc().toIso8601String(),
    'response_due_at': responseDueAt?.toUtc().toIso8601String(),
    'escalated_at': escalatedAt?.toUtc().toIso8601String(),
    'intervention_state': interventionState?.databaseValue,
  };
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

  Map<String, dynamic> toJson() => {
    'event_type': eventType,
    'from_status': fromStatus?.databaseValue,
    'to_status': toStatus.databaseValue,
    'note': note,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

class RiskReportNote {
  const RiskReportNote({
    required this.id,
    required this.riskReportId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.authorName,
  });

  final String id;
  final String riskReportId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final String? authorName;

  factory RiskReportNote.fromJson(Map<String, dynamic> json) {
    final author = _nestedMap(json['author']);
    return RiskReportNote(
      id: json['id'].toString(),
      riskReportId: json['risk_report_id'].toString(),
      authorId: json['author_id'].toString(),
      body: json['body']?.toString() ?? '',
      createdAt: _requiredLocalDate(json['created_at']),
      authorName:
          author['full_name']?.toString() ?? json['author_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'risk_report_id': riskReportId,
    'author_id': authorId,
    'body': body,
    'created_at': createdAt.toUtc().toIso8601String(),
    if (authorName != null) 'author_name': authorName,
  };
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'risk_report_id': riskReportId,
    'order_id': orderId,
    'evidence_type': evidenceType.name,
    'storage_path': storagePath,
    'latitude': latitude,
    'longitude': longitude,
    'captured_at': capturedAt?.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
  };
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

  Map<String, dynamic> toJson() => {
    'risk_report_id': riskReportId,
    'order_id': orderId,
    'state': state.databaseValue,
    'driver_id': driverId,
    'decision_due_at': decisionDueAt.toUtc().toIso8601String(),
    'instruction': instruction,
    'driver_released_at': driverReleasedAt?.toUtc().toIso8601String(),
  };
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
