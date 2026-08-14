enum SupportTicketStatus {
  open('open'),
  inProgress('in_progress'),
  waitingCustomer('waiting_customer'),
  waitingAdmin('waiting_admin'),
  resolved('resolved'),
  closed('closed');

  const SupportTicketStatus(this.databaseValue);

  final String databaseValue;

  bool get isClosed => this == resolved || this == closed;

  static SupportTicketStatus fromDatabase(String? value) => values.firstWhere(
    (item) => item.databaseValue == value,
    orElse: () => open,
  );
}

enum SupportTicketPriority {
  low('low'),
  normal('normal'),
  high('high');

  const SupportTicketPriority(this.databaseValue);

  final String databaseValue;

  static SupportTicketPriority fromDatabase(String? value) => values.firstWhere(
    (item) => item.databaseValue == value,
    orElse: () => normal,
  );
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.customerId,
    required this.subject,
    required this.message,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.orderId,
    this.assignedTo,
    this.riskReportId,
    this.resolution,
    this.customerName,
    this.assignedToName,
    this.firstResponseAt,
    this.responseDueAt,
    this.escalatedAt,
  });

  final String id;
  final String customerId;
  final String? orderId;
  final String? assignedTo;
  final String? riskReportId;
  final String subject;
  final String message;
  final String? resolution;
  final SupportTicketStatus status;
  final SupportTicketPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? customerName;
  final String? assignedToName;
  final DateTime? firstResponseAt;
  final DateTime? responseDueAt;
  final DateTime? escalatedAt;

  bool get responseOverdue =>
      responseDueAt != null &&
      DateTime.now().isAfter(responseDueAt!) &&
      firstResponseAt == null &&
      !status.isClosed;

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final customer = _ticketNestedMap(json['customer']);
    final assignee = _ticketNestedMap(json['assignee']);
    return SupportTicket(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      orderId: json['order_id']?.toString(),
      assignedTo: json['assigned_to']?.toString(),
      riskReportId: json['risk_report_id']?.toString(),
      subject: json['subject']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      resolution: json['resolution']?.toString(),
      status: SupportTicketStatus.fromDatabase(json['status']?.toString()),
      priority: SupportTicketPriority.fromDatabase(
        json['priority']?.toString(),
      ),
      createdAt: _ticketDate(json['created_at']),
      updatedAt: _ticketDate(json['updated_at']),
      customerName: customer['full_name']?.toString(),
      assignedToName: assignee['full_name']?.toString(),
      firstResponseAt: _ticketOptionalDate(json['first_response_at']),
      responseDueAt: _ticketOptionalDate(json['response_due_at']),
      escalatedAt: _ticketOptionalDate(json['escalated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_id': customerId,
    'order_id': orderId,
    'assigned_to': assignedTo,
    'risk_report_id': riskReportId,
    'subject': subject,
    'message': message,
    'resolution': resolution,
    'status': status.databaseValue,
    'priority': priority.databaseValue,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'customer_name': customerName,
    'assigned_to_name': assignedToName,
    'first_response_at': firstResponseAt?.toUtc().toIso8601String(),
    'response_due_at': responseDueAt?.toUtc().toIso8601String(),
    'escalated_at': escalatedAt?.toUtc().toIso8601String(),
  };
}

class SupportTicketDraft {
  const SupportTicketDraft({
    required this.customerId,
    required this.orderId,
    required this.subject,
    required this.message,
    required this.priority,
  });

  final String customerId;
  final String orderId;
  final String subject;
  final String message;
  final SupportTicketPriority priority;

  factory SupportTicketDraft.fromJson(Map<String, dynamic> json) =>
      SupportTicketDraft(
        customerId: json['customer_id']?.toString() ?? '',
        orderId: json['order_id']?.toString() ?? '',
        subject: json['subject']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        priority: SupportTicketPriority.fromDatabase(
          json['priority']?.toString(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'customer_id': customerId,
    'order_id': orderId,
    'subject': subject,
    'message': message,
    'priority': priority.databaseValue,
  };
}

DateTime _ticketDate(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _ticketOptionalDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

Map<String, dynamic> _ticketNestedMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
