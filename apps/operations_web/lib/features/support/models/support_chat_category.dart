import 'support_ticket.dart';

enum SupportChatCategory {
  general('Hỗ trợ thông thường'),
  order('Hỗ trợ đơn hàng');

  const SupportChatCategory(this.label);
  final String label;

  bool includes(SupportTicket ticket) =>
      !ticket.isMonitoring &&
      (this == order) == (ticket.orderId?.trim().isNotEmpty ?? false);
}
