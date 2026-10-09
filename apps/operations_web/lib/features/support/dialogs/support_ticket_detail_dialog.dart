import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show SupportIssue;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/support_ticket_repository.dart';
import '../data/support_completion_repository.dart';
import '../models/support_completion_context.dart';
import '../models/support_ticket.dart';
import '../widgets/support_ticket_actions.dart';
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
    this.completionRepository,
    super.key,
  });

  final SupportTicket ticket;
  final String currentUserId;
  final bool isAdmin;
  final SupportTicketRepository repository;
  final SupportCompletionRepository? completionRepository;

  @override
  State<SupportTicketDetailDialog> createState() =>
      _SupportTicketDetailDialogState();
}

class _SupportTicketDetailDialogState extends State<SupportTicketDetailDialog> {
  List<CaseMessage>? _messages;
  StreamSubscription<List<CaseMessage>>? _messageSubscription;
  bool _busy = false;
  bool _retrying = false;
  String? _error;
  late SupportTicket _ticket;
  StreamSubscription<void>? _ticketSubscription;
  int _revision = 0;
  int _messageRevision = 0;
  bool _showContext = false;
  final _conversationKey = GlobalKey();
  final _contextScrollController = ScrollController();
  SupportCompletionContext? _completion;
  bool _checkingCompletion = false;
  String? _completionError;
  String? _messageError;
  int _completionRevision = 0;
  late final SupportCompletionRepository? _completionRepository =
      widget.completionRepository ??
      (widget.repository is SupabaseSupportTicketRepository
          ? SupabaseSupportCompletionRepository(Supabase.instance.client)
          : null);

  bool get _assignedToMe => _ticket.assignedTo == widget.currentUserId;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    _subscribeToTicket();
    _subscribeToMessages();
    unawaited(_loadMessages());
    unawaited(_checkCompletion());
  }

  void _subscribeToTicket() {
    final repository = widget.repository;
    if (repository is SupportTicketDetailRepository) {
      _ticketSubscription = (repository as SupportTicketDetailRepository)
          .watchTicket(_ticket.id)
          .listen(
            (_) => unawaited(_refreshTicket()),
            onError: (_) {
              if (mounted) {
                setState(() => _error = 'Mất kết nối hồ sơ. Hãy tải lại.');
              }
            },
          );
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await _messageSubscription?.cancel();
      await _ticketSubscription?.cancel();
      if (!mounted) return;
      _subscribeToTicket();
      _subscribeToMessages();
      await Future.wait([_refreshTicket(), _loadMessages()]);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<bool> _checkCompletion() async {
    final repository = _completionRepository;
    if (repository == null) return true;
    final revision = ++_completionRevision;
    setState(() {
      _checkingCompletion = true;
      _completionError = null;
    });
    try {
      final result = await repository.fetchCompletionContext(_ticket);
      if (!mounted || revision != _completionRevision) return false;
      setState(() => _completion = result);
      return result.blockers.isEmpty;
    } catch (_) {
      if (mounted && revision == _completionRevision) {
        setState(
          () => _completionError =
              'Chưa kiểm tra được điều kiện kết thúc. Hãy thử lại.',
        );
      }
      return false;
    } finally {
      if (mounted && revision == _completionRevision) {
        setState(() => _checkingCompletion = false);
      }
    }
  }

  @override
  void dispose() {
    _contextScrollController.dispose();
    unawaited(_messageSubscription?.cancel());
    unawaited(_ticketSubscription?.cancel());
    super.dispose();
  }

  Future<void> _refreshTicket() async {
    final revision = ++_revision;
    try {
      final repository = widget.repository;
      final ticket = repository is SupportTicketDetailRepository
          ? await (repository as SupportTicketDetailRepository).fetchTicket(
              _ticket.id,
            )
          : (await repository.fetchTickets()).firstWhere(
              (item) => item.id == _ticket.id,
            );
      if (mounted && revision == _revision) {
        setState(() {
          _ticket = ticket;
          _error = null;
        });
        await _checkCompletion();
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(
          () => _error =
              'Chưa đồng bộ được hồ sơ. Hãy tải lại trước khi tiếp tục.',
        );
      }
    }
  }

  void _subscribeToMessages() {
    final repository = widget.repository;
    if (repository is! SupportTicketConversationRepository) return;
    final conversations = repository as SupportTicketConversationRepository;
    _messageSubscription = conversations
        .watchMessages(widget.ticket.id)
        .listen(
          (messages) {
            ++_messageRevision;
            if (mounted) {
              setState(() {
                _messages = messages;
                _messageError = null;
              });
            }
          },
          onError: (_) {
            if (mounted) {
              setState(
                () =>
                    _messageError = 'Mất kết nối hội thoại. Vui lòng thử lại.',
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
    final revision = ++_messageRevision;
    try {
      final messages = await conversations.fetchMessages(widget.ticket.id);
      if (mounted && revision == _messageRevision) {
        setState(() {
          _messages = messages;
        });
      }
    } catch (_) {
      if (mounted && revision == _messageRevision) {
        setState(() => _messageError = 'Không tải được lịch sử hội thoại.');
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
      await _refreshTicket();
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
      if (!await _checkCompletion() || !mounted) {
        if (mounted) setState(() => _showContext = true);
        return;
      }
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
      initialDescription: CaseMessageContent.decode(widget.ticket.message).text,
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
    final ticket = _ticket;
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
              SupportTicketDetailHeader(
                ticket: ticket,
                onRefresh: _busy || _retrying ? null : _retry,
              ),
              if (_retrying)
                const LinearProgressIndicator(color: AppColors.accent),
              if (_error != null) _ErrorBanner(message: _error!),
              if (_messageError != null) _ErrorBanner(message: _messageError!),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final chat = SupportLiveConversation(
                      key: _conversationKey,
                      replyTemplate: SupportIssue.fromSubject(
                        ticket.subject,
                      ).replyTemplate(forDriver: ticket.isDriverRequester),
                      messages: _messages,
                      currentUserId: widget.currentUserId,
                      canReply: _assignedToMe && !ticket.status.isClosed,
                      recipientLabel:
                          '${SupportTicketUi.requesterRoleLabel(ticket.requesterRole)} — ${ticket.requesterName ?? SupportTicketUi.shortId(ticket.requesterId)}',
                      lockedMessage: ticket.status.isClosed
                          ? 'Hồ sơ đã kết thúc. Mở lại để tiếp tục trao đổi.'
                          : 'Nhận xử lý hồ sơ để bắt đầu phản hồi',
                      onSend: _sendMessage,
                    );
                    final sidebar = SupportTicketChatSidebar(
                      ticket: ticket,
                      scrollController: _contextScrollController,
                      completion: _completion,
                      completionLoading: _checkingCompletion,
                      completionError: _completionError,
                      onCheckCompletion: _completionRepository == null
                          ? null
                          : _checkCompletion,
                      showOrderContext:
                          widget.repository is SupabaseSupportTicketRepository,
                    );
                    if (constraints.maxWidth < 720) {
                      return Column(
                        children: [
                          Wrap(
                            spacing: AppSpacing.sm,
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _showContext = false),
                                icon: const Icon(Icons.forum_outlined),
                                label: const Text('Trao đổi'),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _showContext = true),
                                icon: const Icon(Icons.inventory_2_outlined),
                                label: const Text('Thông tin hồ sơ'),
                              ),
                            ],
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          Expanded(
                            child: IndexedStack(
                              index: _showContext ? 1 : 0,
                              children: [chat, sidebar],
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: chat),
                        const VerticalDivider(
                          width: 1,
                          color: AppColors.border,
                        ),
                        SizedBox(width: 292, child: sidebar),
                      ],
                    );
                  },
                ),
              ),
              SupportTicketActions(
                ticket: ticket,
                assignedToMe: _assignedToMe,
                isAdmin: widget.isAdmin,
                busy: _busy || _checkingCompletion,
                completionBlocked:
                    _completionError != null ||
                    (_completion?.blockers.isNotEmpty ?? false),
                onShowContext: () {
                  setState(() => _showContext = true);
                  if (_contextScrollController.hasClients) {
                    _contextScrollController.jumpTo(0);
                  }
                },
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
