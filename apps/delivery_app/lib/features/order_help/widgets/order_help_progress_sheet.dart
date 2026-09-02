import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../risk_reports/data/participant_risk_report_query_repository.dart';
import '../../risk_reports/models/participant_risk_report_summary.dart';
import '../data/customer_support_ticket_repository.dart';
import '../utils/order_help_ui.dart';
import 'order_help_conversation.dart';
import 'order_help_event_row.dart';

Future<void> showSupportTicketProgressSheet(
  BuildContext context,
  SupportTicket ticket,
  ParticipantSupportTicketRepository repository,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _SupportProgressLoader(ticket: ticket, repository: repository),
  );
}

class _SupportProgressLoader extends StatefulWidget {
  const _SupportProgressLoader({
    required this.ticket,
    required this.repository,
  });

  final SupportTicket ticket;
  final ParticipantSupportTicketRepository repository;

  @override
  State<_SupportProgressLoader> createState() => _SupportProgressLoaderState();
}

class _SupportProgressLoaderState extends State<_SupportProgressLoader> {
  List<CaseMessage>? _messages;
  StreamSubscription<List<CaseMessage>>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToMessages();
    _loadMessages();
  }

  @override
  void dispose() {
    unawaited(_messageSubscription?.cancel());
    super.dispose();
  }

  void _subscribeToMessages() {
    final repository = widget.repository;
    if (repository is! ParticipantSupportConversationRepository) return;
    final conversations =
        repository as ParticipantSupportConversationRepository;
    _messageSubscription = conversations.watchMessages(widget.ticket.id).listen(
      (messages) {
        if (mounted) setState(() => _messages = messages);
      },
    );
  }

  Future<void> _loadMessages() async {
    final repository = widget.repository;
    if (repository is! ParticipantSupportConversationRepository) {
      if (mounted) setState(() => _messages = const []);
      return;
    }
    final conversations =
        repository as ParticipantSupportConversationRepository;
    final messages = await conversations.fetchMessages(widget.ticket.id);
    if (mounted) setState(() => _messages = messages);
  }

  Future<void> _send(String body) async {
    final repository = widget.repository;
    if (repository is! ParticipantSupportConversationRepository) return;
    final conversations =
        repository as ParticipantSupportConversationRepository;
    await conversations.postMessage(widget.ticket.id, body);
    await _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    return _ProgressSheet(
      title: ticket.subject,
      recordId: ticket.id,
      statusLabel: OrderHelpUi.supportStatusLabel(ticket.status),
      statusColor: OrderHelpUi.supportStatusColor(ticket.status),
      statusIcon: OrderHelpUi.supportStatusIcon(ticket.status),
      description: ticket.message,
      resolution: ticket.resolution,
      updatedAt: ticket.updatedAt,
      messages: _messages,
      onSend: ticket.status.isClosed ? null : _send,
    );
  }
}

Future<void> showRiskReportProgressSheet(
  BuildContext context,
  ParticipantRiskReportSummary report,
  ParticipantRiskReportQueryRepository repository,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RiskProgressLoader(report: report, repository: repository),
  );
}

class _RiskProgressLoader extends StatefulWidget {
  const _RiskProgressLoader({required this.report, required this.repository});

  final ParticipantRiskReportSummary report;
  final ParticipantRiskReportQueryRepository repository;

  @override
  State<_RiskProgressLoader> createState() => _RiskProgressLoaderState();
}

class _RiskProgressLoaderState extends State<_RiskProgressLoader> {
  late final Future<List<RiskReportEvent>> _events = widget.repository
      .fetchEvents(widget.report.id);
  List<CaseMessage>? _messages;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final repository = widget.repository;
    if (repository is! ParticipantRiskConversationRepository) {
      if (mounted) setState(() => _messages = const []);
      return;
    }
    final conversations = repository as ParticipantRiskConversationRepository;
    final messages = await conversations.fetchMessages(widget.report.id);
    if (mounted) setState(() => _messages = messages);
  }

  Future<void> _send(String body) async {
    final repository = widget.repository;
    if (repository is! ParticipantRiskConversationRepository) return;
    final conversations = repository as ParticipantRiskConversationRepository;
    await conversations.postMessage(widget.report.id, body);
    await _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return FutureBuilder<List<RiskReportEvent>>(
      future: _events,
      builder: (context, snapshot) => _ProgressSheet(
        title: report.title,
        recordId: report.id,
        statusLabel: OrderHelpUi.riskStatusLabel(report.status),
        statusColor: OrderHelpUi.riskStatusColor(report.status),
        statusIcon: OrderHelpUi.riskStatusIcon(report.status),
        description: report.description,
        resolution: report.resolution,
        updatedAt: report.updatedAt,
        events: snapshot.data,
        messages: _messages,
        onSend: report.status.isClosed ? null : _send,
      ),
    );
  }
}

class _ProgressSheet extends StatelessWidget {
  const _ProgressSheet({
    required this.title,
    required this.recordId,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.description,
    required this.updatedAt,
    this.resolution,
    this.events,
    this.messages,
    this.onSend,
  });

  final String title;
  final String recordId;
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String description;
  final String? resolution;
  final DateTime updatedAt;
  final List<RiskReportEvent>? events;
  final List<CaseMessage>? messages;
  final Future<void> Function(String body)? onSend;

  @override
  Widget build(BuildContext context) {
    final shortId = recordId.length <= 8
        ? recordId.toUpperCase()
        : recordId.substring(0, 8).toUpperCase();
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppShadow.elevated,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.md,
                    ),
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.headingMedium),
                        Text('#$shortId', style: AppTextStyles.mono),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                children: [
                  _StatusCard(
                    label: statusLabel,
                    color: statusColor,
                    icon: statusIcon,
                    updatedAt: updatedAt,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ContentCard(title: 'Nội dung đã gửi', body: description),
                  if ((resolution ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ContentCard(
                      title: 'Kết quả xử lý',
                      body: resolution!,
                      color: AppColors.success,
                    ),
                  ],
                  if (events != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text('Tiến độ', style: AppTextStyles.headingSmall),
                    const SizedBox(height: AppSpacing.md),
                    for (final event in events!)
                      OrderHelpEventRow(event: event),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  OrderHelpConversation(messages: messages, onSend: onSend),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.label,
    required this.color,
    required this.icon,
    required this.updatedAt,
  });

  final String label;
  final Color color;
  final IconData icon;
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.lg,
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTextStyles.labelLarge)),
          Text(
            OrderHelpUi.dateTime(updatedAt),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.title, required this.body, this.color});

  final String title;
  final String body;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: color?.withValues(alpha: 0.3) ?? AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
