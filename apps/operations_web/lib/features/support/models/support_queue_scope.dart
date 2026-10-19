import 'support_ticket.dart';

enum SupportQueueScope {
  active('Cần xử lý'),
  mine('Tôi phụ trách'),
  needsReply('Cần phản hồi'),
  unassigned('Chưa tiếp nhận'),
  finished('Kết thúc'),
  automatic('Nhật ký tự động');

  const SupportQueueScope(this.label);
  final String label;

  bool includes(SupportTicket ticket, String actorId) => switch (this) {
    active => ticket.needsSupportAttention,
    mine => ticket.needsSupportAttention && ticket.assignedTo == actorId,
    needsReply => ticket.needsReply,
    unassigned => ticket.needsSupportAttention && ticket.assignedTo == null,
    finished => ticket.status.isClosed && !ticket.isAutomaticMonitoringNotice,
    automatic => ticket.isAutomaticMonitoringNotice,
  };
}
