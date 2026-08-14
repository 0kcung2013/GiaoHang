-- Notification categories emitted by the case-management RPCs and SLA job.
ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'order_update',
    'promotion',
    'system',
    'support_ticket_created',
    'support_ticket_accepted',
    'support_ticket_status',
    'support_ticket_admin_required',
    'support_ticket_message',
    'support_ticket_customer_message',
    'support_ticket_converted',
    'support_ticket_sla_overdue',
    'risk_report_accepted',
    'risk_report_status',
    'risk_report_admin_required',
    'risk_report_message',
    'risk_report_participant_message',
    'risk_report_sla_overdue'
  ));
