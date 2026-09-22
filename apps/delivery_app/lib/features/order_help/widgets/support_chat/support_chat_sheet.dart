import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../data/customer_support_ticket_repository.dart';
import '../../utils/order_help_ui.dart';
import 'support_chat_composer.dart';
import 'support_chat_header.dart';
import 'support_chat_messages.dart';

Future<SupportTicket?> showParticipantSupportChatSheet(
  BuildContext context, {
  required String requesterId,
  required String requesterRole,
  required String orderId,
  required String subject,
  required SupportTicketPriority priority,
  required ParticipantSupportTicketRepository repository,
  String? orderCode,
  SupportTicket? initialTicket,
}) {
  return showModalBottomSheet<SupportTicket>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.primary.withValues(alpha: 0.42),
    builder: (_) => SupportChatSheet(
      requesterId: requesterId,
      requesterRole: requesterRole,
      orderId: orderId,
      orderCode: orderCode,
      subject: subject,
      priority: priority,
      repository: repository,
      initialTicket: initialTicket,
    ),
  );
}

class SupportChatSheet extends StatefulWidget {
  const SupportChatSheet({
    required this.requesterId,
    required this.requesterRole,
    required this.orderId,
    required this.subject,
    required this.priority,
    required this.repository,
    this.orderCode,
    this.initialTicket,
    super.key,
  });

  final String requesterId;
  final String requesterRole;
  final String orderId;
  final String? orderCode;
  final String subject;
  final SupportTicketPriority priority;
  final ParticipantSupportTicketRepository repository;
  final SupportTicket? initialTicket;

  @override
  State<SupportChatSheet> createState() => _SupportChatSheetState();
}

class _SupportChatSheetState extends State<SupportChatSheet> {
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<List<CaseMessage>>? _messageSubscription;
  StreamSubscription<List<SupportTicket>>? _ticketSubscription;

  SupportTicket? _ticket;
  List<CaseMessage>? _messages;
  String? _pendingBody;
  String? _error;
  bool _sending = false;
  bool _connected = false;
  bool _streamFailed = false;

  ParticipantSupportConversationRepository? get _conversations {
    final repository = widget.repository;
    return repository is ParticipantSupportConversationRepository
        ? repository as ParticipantSupportConversationRepository
        : null;
  }

  @override
  void initState() {
    super.initState();
    _ticket = widget.initialTicket;
    _messages = _ticket == null ? const [] : null;
    if (_ticket != null) {
      unawaited(_connectToTicket());
      _watchTicket();
    }
  }

  @override
  void dispose() {
    unawaited(_messageSubscription?.cancel());
    unawaited(_ticketSubscription?.cancel());
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _connectToTicket() async {
    final ticket = _ticket;
    final conversations = _conversations;
    if (ticket == null || conversations == null) {
      if (mounted) {
        setState(() {
          _messages ??= const [];
          _connected = false;
        });
      }
      return;
    }

    await _messageSubscription?.cancel();
    if (!mounted) return;
    setState(() {
      _streamFailed = false;
      _connected = false;
    });
    _messageSubscription = conversations
        .watchMessages(ticket.id)
        .listen(
          (messages) {
            if (!mounted) return;
            setState(() {
              _messages = messages;
              _connected = true;
              _streamFailed = false;
            });
            _scrollToBottom();
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _connected = false;
              _streamFailed = true;
            });
          },
          onDone: () {
            if (mounted) setState(() => _connected = false);
          },
        );

    try {
      final messages = await conversations.fetchMessages(ticket.id);
      if (!mounted || _ticket?.id != ticket.id) return;
      setState(() {
        _messages = messages;
        _connected = true;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages ??= const [];
        _streamFailed = true;
        _error = 'Chưa đồng bộ được tin nhắn. Chạm trạng thái để thử lại.';
      });
    }
  }

  void _watchTicket() {
    if (widget.orderId.isEmpty) return;
    unawaited(_ticketSubscription?.cancel());
    _ticketSubscription = widget.repository
        .watchForOrder(widget.orderId)
        .listen((tickets) {
          final currentId = _ticket?.id;
          if (!mounted || currentId == null) return;
          for (final ticket in tickets) {
            if (ticket.id == currentId) {
              setState(() => _ticket = ticket);
              break;
            }
          }
        });
  }

  Future<void> _send() async {
    final body = _composerController.text.trim();
    if (body.isEmpty || _sending) return;
    if (_ticket == null && body.length < 10) {
      setState(() {
        _error = 'Hãy mô tả vấn đề rõ hơn bằng ít nhất 10 ký tự.';
      });
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _pendingBody = body;
    });
    _composerController.clear();
    _scrollToBottom();

    try {
      if (_ticket == null) {
        final ticket = await widget.repository.create(
          SupportTicketDraft(
            requesterId: widget.requesterId,
            orderId: widget.orderId,
            subject: widget.subject,
            message: body,
            priority: widget.priority,
          ),
        );
        if (!mounted) return;
        setState(() {
          _ticket = ticket;
          _messages = [
            CaseMessage(
              id: 'local-initial',
              caseId: ticket.id,
              senderId: widget.requesterId,
              senderRole: widget.requesterRole,
              visibility: CaseMessageVisibility.public,
              body: body,
              createdAt: DateTime.now(),
            ),
          ];
          _pendingBody = null;
        });
        _watchTicket();
        await _connectToTicket();
      } else {
        final conversations = _conversations;
        if (conversations == null) {
          throw const CustomerSupportTicketException(
            'Kênh trò chuyện hiện chưa sẵn sàng.',
          );
        }
        await conversations.postMessage(_ticket!.id, body);
        if (!mounted) return;
        setState(() => _pendingBody = null);
        final messages = await conversations.fetchMessages(_ticket!.id);
        if (mounted) setState(() => _messages = messages);
      }
      _scrollToBottom();
    } on CustomerSupportTicketException catch (error) {
      _restoreFailedMessage(body, error.message);
    } catch (_) {
      _restoreFailedMessage(
        body,
        'Chưa gửi được tin nhắn. Vui lòng kiểm tra kết nối và thử lại.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _restoreFailedMessage(String body, String message) {
    if (!mounted) return;
    setState(() {
      _pendingBody = null;
      _error = message;
      if (_composerController.text.isEmpty) {
        _composerController.text = body;
        _composerController.selection = TextSelection.collapsed(
          offset: body.length,
        );
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppDuration.normal,
          curve: AppCurve.decelerate,
        ),
      );
    });
  }

  void _close() => Navigator.pop(context, _ticket);

  String get _connectionLabel {
    if (_ticket == null) return 'Sẵn sàng hỗ trợ trực tiếp';
    if (_streamFailed) return 'Mất kết nối · Chạm để thử lại';
    if (_connected) return 'Đang kết nối thời gian thực';
    return 'Đang đồng bộ cuộc trò chuyện...';
  }

  String get _orderLabel {
    final code = widget.orderCode?.trim();
    if (code != null && code.isNotEmpty) return 'Đơn $code';
    final id = widget.orderId;
    final shortId = id.length <= 8 ? id : id.substring(0, 8);
    return 'Đơn #${shortId.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    final statusLabel = ticket == null
        ? 'Chưa gửi'
        : OrderHelpUi.supportStatusLabel(ticket.status);
    final statusColor = ticket == null
        ? AppColors.info
        : OrderHelpUi.supportStatusColor(ticket.status);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: Material(
          key: const Key('support-chat-sheet'),
          color: AppColors.bgLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SupportChatHeader(
                connectionLabel: _connectionLabel,
                connected: ticket == null || _connected,
                orderLabel: _orderLabel,
                subject: widget.subject,
                statusLabel: statusLabel,
                statusColor: statusColor,
                onClose: _close,
                onRetry: _streamFailed
                    ? () => unawaited(_connectToTicket())
                    : null,
              ),
              Expanded(
                child: SupportChatMessages(
                  messages: _messages,
                  requesterId: widget.requesterId,
                  scrollController: _scrollController,
                  pendingBody: _pendingBody,
                ),
              ),
              SupportChatComposer(
                controller: _composerController,
                sending: _sending,
                started: ticket != null,
                closed: ticket?.status.isClosed ?? false,
                error: _error,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
