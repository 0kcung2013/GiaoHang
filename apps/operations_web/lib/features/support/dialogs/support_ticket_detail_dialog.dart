import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/support_ticket_repository.dart';
import '../models/support_ticket.dart';
import '../models/support_ticket_policy.dart';
import '../utils/support_ticket_ui.dart';
import '../widgets/support_live_conversation.dart';
import '../widgets/support_ticket_chat_sidebar.dart';
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
  StreamSubscription<List<CaseMessage>>? _messageSubscription;
  bool _busy = false;
  String? _error;

  bool get _assignedToMe => widget.ticket.assignedTo == widget.currentUserId;

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
    if (repository is! SupportTicketConversationRepository) return;
    final conversations = repository as SupportTicketConversationRepository;
    _messageSubscription = conversations
        .watchMessages(widget.ticket.id)
        .listen(
          (messages) {
            if (mounted) setState(() => _messages = messages);
          },
          onError: (_) {
            if (mounted) {
              setState(
                () => _error = 'Mất kết nối hội thoại. Vui lòng thử lại.',
              );
            }
          },
        );
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
      if (mounted) {
        setState(() => _error = 'Không tải được lịch sử hội thoại.');
      }
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
    await _run(
      () => (repository as SupportTicketCommandRepository).acceptTicket(
        widget.ticket.id,
      ),
    );
  }

  Future<void> _takeOver() async {
    final repository = widget.repository;
    if (repository is! SupportTicketCommandRepository) return;
    await _run(
      () => (repository as SupportTicketCommandRepository).takeOverTicket(
        widget.ticket.id,
      ),
    );
  }

  Future<void> _transition(SupportTicketStatus status) async {
    final repository = widget.repository;
    if (repository is! SupportTicketCommandRepository) return;
    String? resolution;
    if (status.isClosed) {
      resolution = await showSupportResolutionDialog(context);
      if (resolution == null || !mounted) return;
    }
    await _run(
      () => (repository as SupportTicketCommandRepository).transitionTicket(
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
    final draft = await showSupportRiskConversionDialog(
      context,
      initialTitle: widget.ticket.subject,
      initialDescription: widget.ticket.message,
      needsComponent: widget.ticket.orderId == null,
    );
    if (draft == null || !mounted) return;
    await _run(
      () => (repository as SupportTicketRiskRepository).convertToRisk(
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
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: screen.height - AppSpacing.xl3,
        ),
        child: Material(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SupportTicketDetailHeader(ticket: ticket),
              if (_error != null) _ErrorBanner(message: _error!),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final chat = SupportLiveConversation(
                      messages: _messages,
                      currentUserId: widget.currentUserId,
                      canReply: _assignedToMe && !ticket.status.isClosed,
                      onSend: _sendMessage,
                    );
                    final sidebar = SupportTicketChatSidebar(ticket: ticket);
                    if (constraints.maxWidth < 720) {
                      return Column(
                        children: [
                          SizedBox(height: 210, child: sidebar),
                          const Divider(height: 1, color: AppColors.border),
                          Expanded(child: chat),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        SizedBox(width: 292, child: sidebar),
                        const VerticalDivider(
                          width: 1,
                          color: AppColors.border,
                        ),
                        Expanded(child: chat),
                      ],
                    );
                  },
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.sm,
    ),
    color: AppColors.error.withValues(alpha: 0.08),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 17,
          color: AppColors.error,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) {
    final transitions = SupportTicketPolicy.allowedTransitions(ticket.status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (assignedToMe && ticket.riskReportId == null)
            TextButton.icon(
              onPressed: busy ? null : onConvert,
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text('Chuyển báo cáo sự cố'),
            ),
          const Spacer(),
          if (ticket.assignedTo == null)
            FilledButton.icon(
              key: const Key('accept-support-ticket'),
              onPressed: busy ? null : onAccept,
              icon: const Icon(Icons.person_add_alt_rounded, size: 18),
              label: const Text('Nhận xử lý'),
            )
          else if (!assignedToMe && isAdmin)
            OutlinedButton.icon(
              key: const Key('takeover-support-ticket'),
              onPressed: busy ? null : onTakeOver,
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
              label: const Text('Tiếp quản'),
            )
          else if (!assignedToMe)
            Text(
              'Đã có người phụ trách',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textMuted,
              ),
            )
          else if (transitions.isNotEmpty)
            PopupMenuButton<SupportTicketStatus>(
              enabled: !busy,
              tooltip: 'Cập nhật trạng thái',
              onSelected: onTransition,
              itemBuilder: (context) => [
                for (final status in transitions)
                  PopupMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Icon(
                          SupportTicketUi.statusIcon(status),
                          size: 18,
                          color: SupportTicketUi.statusColor(status),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(SupportTicketUi.statusLabel(status)),
                      ],
                    ),
                  ),
              ],
              child: IgnorePointer(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.sync_alt_rounded, size: 18),
                  label: const Text('Cập nhật trạng thái'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
