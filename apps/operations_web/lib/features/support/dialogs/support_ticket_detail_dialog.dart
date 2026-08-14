import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/support_ticket_repository.dart';
import '../models/support_ticket.dart';
import '../models/support_ticket_policy.dart';
import '../utils/support_ticket_ui.dart';
import '../widgets/support_case_conversation.dart';
import '../widgets/support_ticket_detail_content.dart';
import 'support_ticket_operation_dialogs.dart';

class SupportTicketDetailDialog extends StatefulWidget {
  const SupportTicketDetailDialog({
    required this.ticket,
    required this.currentUserId,
    required this.isAdmin,
    required this.repository,
    super.key,
  });

  final SupportTicket ticket;
  final String currentUserId;
  final bool isAdmin;
  final SupportTicketRepository repository;

  @override
  State<SupportTicketDetailDialog> createState() =>
      _SupportTicketDetailDialogState();
}

class _SupportTicketDetailDialogState extends State<SupportTicketDetailDialog> {
  List<CaseMessage>? _messages;
  bool _busy = false;
  String? _error;

  bool get _assignedToMe => widget.ticket.assignedTo == widget.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final repository = widget.repository;
    if (repository is! SupportTicketConversationRepository) {
      if (mounted) setState(() => _messages = const []);
      return;
    }
    final conversations = repository as SupportTicketConversationRepository;
    try {
      final messages = await conversations.fetchMessages(widget.ticket.id);
      if (mounted) setState(() => _messages = messages);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được trao đổi hồ sơ.');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể cập nhật hồ sơ.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    final repository = widget.repository;
    if (repository is! SupportTicketCommandRepository) return;
    final commands = repository as SupportTicketCommandRepository;
    await _run(() => commands.acceptTicket(widget.ticket.id));
  }

  Future<void> _takeOver() async {
    final repository = widget.repository;
    if (repository is! SupportTicketCommandRepository) return;
    final commands = repository as SupportTicketCommandRepository;
    await _run(() => commands.takeOverTicket(widget.ticket.id));
  }

  Future<void> _transition(SupportTicketStatus status) async {
    final repository = widget.repository;
    if (repository is! SupportTicketCommandRepository) return;
    final commands = repository as SupportTicketCommandRepository;
    String? resolution;
    if (status.isClosed) {
      resolution = await showSupportResolutionDialog(context);
      if (resolution == null || !mounted) return;
    }
    await _run(
      () => commands.transitionTicket(
        widget.ticket.id,
        status,
        resolution: resolution,
      ),
    );
  }

  Future<void> _sendMessage(
    String body,
    CaseMessageVisibility visibility,
  ) async {
    final repository = widget.repository;
    if (repository is! SupportTicketConversationRepository) return;
    final conversations = repository as SupportTicketConversationRepository;
    await conversations.postMessage(
      widget.ticket.id,
      body,
      visibility: visibility,
    );
    await _loadMessages();
  }

  Future<void> _convertToRisk() async {
    final repository = widget.repository;
    if (repository is! SupportTicketRiskRepository) return;
    final riskCommands = repository as SupportTicketRiskRepository;
    final draft = await showSupportRiskConversionDialog(
      context,
      initialTitle: widget.ticket.subject,
      initialDescription: widget.ticket.message,
      needsComponent: widget.ticket.orderId == null,
    );
    if (draft == null || !mounted) return;
    await _run(
      () => riskCommands.convertToRisk(
        widget.ticket.id,
        category: draft.category.databaseValue,
        severity: draft.severity.name,
        title: draft.title,
        description: draft.description,
        component: draft.component,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final statusColor = SupportTicketUi.statusColor(ticket.status);
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: screen.height - AppSpacing.xl3,
        ),
        child: Material(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SupportTicketDetailHeader(ticket: ticket),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          SupportTicketBadge(
                            icon: SupportTicketUi.statusIcon(ticket.status),
                            label: SupportTicketUi.statusLabel(ticket.status),
                            color: statusColor,
                          ),
                          SupportTicketBadge(
                            icon: Icons.flag_outlined,
                            label:
                                'Ưu tiên ${SupportTicketUi.priorityLabel(ticket.priority)}',
                            color: SupportTicketUi.priorityColor(
                              ticket.priority,
                            ),
                          ),
                          if (ticket.responseOverdue)
                            const SupportTicketBadge(
                              icon: Icons.timer_off_outlined,
                              label: 'Quá hạn phản hồi',
                              color: AppColors.error,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SupportTicketContext(ticket: ticket),
                      const SizedBox(height: AppSpacing.lg),
                      SupportContentBlock(
                        title: 'Nội dung ban đầu',
                        body: ticket.message,
                      ),
                      if ((ticket.resolution ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        SupportContentBlock(
                          title: 'Kết luận',
                          body: ticket.resolution!,
                          color: AppColors.success,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      SupportCaseConversation(
                        messages: _messages,
                        currentUserId: widget.currentUserId,
                        canReply: _assignedToMe && !ticket.status.isClosed,
                        onSend: _sendMessage,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _Actions(
                ticket: ticket,
                assignedToMe: _assignedToMe,
                isAdmin: widget.isAdmin,
                busy: _busy,
                onAccept: _accept,
                onTakeOver: _takeOver,
                onTransition: _transition,
                onConvert: _convertToRisk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.ticket,
    required this.assignedToMe,
    required this.isAdmin,
    required this.busy,
    required this.onAccept,
    required this.onTakeOver,
    required this.onTransition,
    required this.onConvert,
  });

  final SupportTicket ticket;
  final bool assignedToMe;
  final bool isAdmin;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onTakeOver;
  final ValueChanged<SupportTicketStatus> onTransition;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: const BoxDecoration(
      color: AppColors.bgLight,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (ticket.assignedTo == null)
            FilledButton.icon(
              key: const Key('accept-support-ticket'),
              onPressed: busy ? null : onAccept,
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Nhận xử lý'),
            )
          else if (!assignedToMe && isAdmin)
            OutlinedButton.icon(
              key: const Key('takeover-support-ticket'),
              onPressed: busy ? null : onTakeOver,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Admin tiếp quản'),
            )
          else if (!assignedToMe)
            OutlinedButton.icon(
              onPressed: null,
              icon: Icon(Icons.lock_person_outlined),
              label: Text('Đã có người phụ trách'),
            ),
          if (assignedToMe && ticket.riskReportId == null) ...[
            OutlinedButton.icon(
              onPressed: busy ? null : onConvert,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Chuyển báo cáo sự cố'),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (assignedToMe)
            for (final status in SupportTicketPolicy.allowedTransitions(
              ticket.status,
            )) ...[
              OutlinedButton(
                onPressed: busy ? null : () => onTransition(status),
                child: Text(SupportTicketUi.statusLabel(status)),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
        ],
      ),
    ),
  );
}
