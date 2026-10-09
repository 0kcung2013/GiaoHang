import 'support_ticket.dart';

abstract final class SupportTicketPolicy {
  static List<SupportTicketStatus> allowedTransitions(
    SupportTicketStatus status,
  ) => switch (status) {
    SupportTicketStatus.open => const [],
    SupportTicketStatus.inProgress => const [SupportTicketStatus.resolved],
    SupportTicketStatus.waitingCustomer ||
    SupportTicketStatus.waitingAdmin => const [SupportTicketStatus.resolved],
    SupportTicketStatus.resolved => const [SupportTicketStatus.inProgress],
    SupportTicketStatus.closed => const [SupportTicketStatus.inProgress],
  };
}
