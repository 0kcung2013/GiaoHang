import 'support_ticket.dart';

abstract final class SupportTicketPolicy {
  static List<SupportTicketStatus> allowedTransitions(
    SupportTicketStatus status,
  ) => switch (status) {
    SupportTicketStatus.open => const [],
    SupportTicketStatus.inProgress => const [
      SupportTicketStatus.waitingCustomer,
      SupportTicketStatus.waitingAdmin,
      SupportTicketStatus.resolved,
      SupportTicketStatus.closed,
    ],
    SupportTicketStatus.waitingCustomer ||
    SupportTicketStatus.waitingAdmin => const [
      SupportTicketStatus.inProgress,
      SupportTicketStatus.resolved,
      SupportTicketStatus.closed,
    ],
    SupportTicketStatus.resolved => const [
      SupportTicketStatus.inProgress,
      SupportTicketStatus.closed,
    ],
    SupportTicketStatus.closed => const [SupportTicketStatus.inProgress],
  };
}
