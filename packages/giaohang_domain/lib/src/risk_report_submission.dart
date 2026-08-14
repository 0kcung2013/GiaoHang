import 'risk_report.dart';

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

  factory RiskReportSubmission.fromJson(Map<String, dynamic> json) =>
      RiskReportSubmission(
        reportId: json['report_id']?.toString() ?? '',
        orderId: json['order_id']?.toString() ?? '',
        category: RiskCategory.fromDatabase(json['category']?.toString()),
        description: json['description']?.toString() ?? '',
        photoPaths: List<String>.from(json['photo_paths'] as List? ?? const []),
        messageIds: List<String>.from(json['message_ids'] as List? ?? const []),
        latitude: _optionalDouble(json['latitude']),
        longitude: _optionalDouble(json['longitude']),
        locationCapturedAt: _optionalLocalDate(json['location_captured_at']),
      );

  Map<String, dynamic> toJson() => {
    'report_id': reportId,
    'order_id': orderId,
    'category': category.databaseValue,
    'description': description,
    'photo_paths': photoPaths,
    'message_ids': messageIds,
    'latitude': latitude,
    'longitude': longitude,
    'location_captured_at': locationCapturedAt?.toUtc().toIso8601String(),
  };

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

  factory RiskReportSubmissionResult.fromJson(Map<String, dynamic> json) =>
      RiskReportSubmissionResult(
        reportId: json['report_id']?.toString() ?? '',
        status: RiskStatus.fromDatabase(json['status']?.toString()),
      );

  Map<String, dynamic> toJson() => {
    'report_id': reportId,
    'status': status.databaseValue,
  };
}

class RiskReportDraft {
  const RiskReportDraft({
    required this.trackingCode,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    this.scope = RiskScope.order,
    this.component,
  });

  final String trackingCode;
  final RiskScope scope;
  final String? component;
  final RiskCategory category;
  final RiskSeverity severity;
  final String title;
  final String description;

  bool get isSystemIncident => scope == RiskScope.system;

  factory RiskReportDraft.fromJson(Map<String, dynamic> json) =>
      RiskReportDraft(
        trackingCode: json['tracking_code']?.toString() ?? '',
        scope: RiskScope.fromDatabase(json['scope']?.toString()),
        component: json['component']?.toString(),
        category: RiskCategory.fromDatabase(json['category']?.toString()),
        severity: RiskSeverity.fromDatabase(json['severity']?.toString()),
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'tracking_code': trackingCode,
    'scope': scope.databaseValue,
    'component': component,
    'category': category.databaseValue,
    'severity': severity.name,
    'title': title,
    'description': description,
  };
}

DateTime? _optionalLocalDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

double? _optionalDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
