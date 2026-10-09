import 'support_ticket.dart';

enum SupportQueueScope {
  active('Cần xử lý'),
  mine('Tôi phụ trách'),
  needsReply('Cần phản hồi'),
  unassigned('Chưa tiếp nhận'),
  finished('Kết thúc');

  const SupportQueueScope(this.label);
  final String label;

  bool includes(SupportTicket ticket, String actorId) => switch (this) {
    active => !ticket.status.isClosed,
    mine => !ticket.status.isClosed && ticket.assignedTo == actorId,
    needsReply => ticket.needsReply,
    unassigned => !ticket.status.isClosed && ticket.assignedTo == null,
    finished => ticket.status.isClosed,
  };
}
