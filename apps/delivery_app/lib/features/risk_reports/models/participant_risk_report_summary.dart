import 'package:giaohang_domain/giaohang_domain.dart';

class ParticipantRiskReportSummary {
  const ParticipantRiskReportSummary({
    required this.id,
    required this.orderId,
    required this.category,
    required this.status,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.resolution,
    this.triageDueAt,
  });

  final String id;
  final String orderId;
  final RiskCategory category;
  final RiskStatus status;
  final String title;
  final String description;
  final String? resolution;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? triageDueAt;

  factory ParticipantRiskReportSummary.fromJson(Map<String, dynamic> json) {
    return ParticipantRiskReportSummary(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      category: RiskCategory.fromDatabase(json['category']?.toString()),
      status: RiskStatus.fromDatabase(json['status']?.toString()),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      resolution: json['resolution']?.toString(),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      triageDueAt: _optionalDate(json['triage_due_at']),
    );
  }
}

DateTime _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
    DateTime.fromMillisecondsSinceEpoch(0);

DateTime? _optionalDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
