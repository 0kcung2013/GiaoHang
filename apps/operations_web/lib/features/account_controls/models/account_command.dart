import 'dart:math';

/// Immutable retry payload: a timeout must never create a second decision.
class AccountCommand {
  AccountCommand({
    required this.userId,
    required this.action,
    required this.reason,
    this.durationMinutes,
    this.expectedEventId,
    this.riskReportId,
    this.ticketId,
    String? requestId,
  }) : requestId = requestId ?? _uuid();
  final String userId, action, reason, requestId;
  final int? durationMinutes;
  final String? expectedEventId, riskReportId, ticketId;
  Map<String, dynamic> toJson() => {
    'p_user_id': userId,
    'p_action': action,
    'p_reason': reason,
    'p_request_id': requestId,
    'p_duration_minutes': durationMinutes,
    'p_expected_event_id': expectedEventId,
    'p_risk_report_id': riskReportId,
    'p_ticket_id': ticketId,
  };
  static String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
