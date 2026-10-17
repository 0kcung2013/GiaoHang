import 'package:giaohang_domain/giaohang_domain.dart';

enum OrderHelpRecordType { supportTicket, riskReport }

class OrderHelpReceipt {
  const OrderHelpReceipt({
    required this.id,
    required this.type,
    required this.created,
    this.supportStatus,
    this.riskStatus,
  });

  final String id;
  final OrderHelpRecordType type;
  final bool created;
  final SupportTicketStatus? supportStatus;
  final RiskStatus? riskStatus;
}
