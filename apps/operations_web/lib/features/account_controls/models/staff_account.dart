class StaffAccount {
  const StaffAccount({
    required this.id,
    required this.name,
    required this.role,
    required this.disabled,
    required this.activeOrders,
    this.email,
    this.phone,
    this.eventId,
    this.disabledUntil,
    this.reason,
    this.actorName,
    this.decidedAt,
  });
  final String id, name, role;
  final bool disabled;
  final int activeOrders;
  final String? email, phone, eventId, reason, actorName;
  final DateTime? disabledUntil, decidedAt;
  bool get controllable => role == 'customer' || role == 'driver';
  factory StaffAccount.fromJson(Map<String, dynamic> json) => StaffAccount(
    id: json['id'] as String,
    name: json['full_name'] as String? ?? '',
    role: json['role'] as String,
    disabled: json['disabled'] as bool,
    activeOrders: (json['active_orders'] as num).toInt(),
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    eventId: json['event_id'] as String?,
    reason: json['reason'] as String?,
    actorName: json['actor_name'] as String?,
    disabledUntil: json['disabled_until'] == null
        ? null
        : DateTime.parse(json['disabled_until'] as String),
    decidedAt: json['decided_at'] == null
        ? null
        : DateTime.parse(json['decided_at'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': name,
    'role': role,
    'disabled': disabled,
    'active_orders': activeOrders,
    'email': email,
    'phone': phone,
    'event_id': eventId,
    'reason': reason,
    'actor_name': actorName,
    'disabled_until': disabledUntil?.toIso8601String(),
    'decided_at': decidedAt?.toIso8601String(),
  };
}

class AccountEvent {
  const AccountEvent({
    required this.id,
    required this.sequence,
    required this.action,
    required this.reason,
    required this.actorRole,
    required this.createdAt,
    this.actorName,
    this.disabledUntil,
    this.riskReportId,
    this.ticketId,
  });
  final String id, action, reason, actorRole;
  final int sequence;
  final String? actorName, riskReportId, ticketId;
  final DateTime createdAt;
  final DateTime? disabledUntil;
  factory AccountEvent.fromJson(Map<String, dynamic> json) => AccountEvent(
    id: json['id'] as String,
    sequence: (json['event_seq'] as num).toInt(),
    action: json['action'] as String,
    reason: json['reason'] as String,
    actorRole: json['actor_role'] as String,
    actorName: json['actor_name'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    disabledUntil: json['disabled_until'] == null
        ? null
        : DateTime.parse(json['disabled_until'] as String),
    riskReportId: json['risk_report_id'] as String?,
    ticketId: json['ticket_id'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'event_seq': sequence,
    'action': action,
    'reason': reason,
    'actor_role': actorRole,
    'actor_name': actorName,
    'created_at': createdAt.toIso8601String(),
    'disabled_until': disabledUntil?.toIso8601String(),
    'risk_report_id': riskReportId,
    'ticket_id': ticketId,
  };
}

class AccountPage<T> {
  const AccountPage({
    required this.rows,
    required this.hasMore,
    required this.serverNow,
  });
  final List<T> rows;
  final bool hasMore;
  final DateTime serverNow;
}
