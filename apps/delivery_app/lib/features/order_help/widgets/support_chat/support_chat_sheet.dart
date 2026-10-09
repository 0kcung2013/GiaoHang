import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_storage/giaohang_storage.dart';

import '../../controllers/support_chat_attachment_draft.dart';
import '../../data/customer_support_ticket_repository.dart';
import '../../utils/order_help_ui.dart';
import 'support_chat_composer.dart';
import 'support_chat_header.dart';
import 'support_chat_messages.dart';
import 'support_chat_attachment_preview.dart';

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
    this.attachmentDraft,
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
  final SupportChatAttachmentDraft? attachmentDraft;

  @override
  State<SupportChatSheet> createState() => _SupportChatSheetState();
}

class _SupportChatSheetState extends State<SupportChatSheet> {
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();
  late final SupportChatAttachmentDraft _attachments;
  bool _selectingImages = false;
  StreamSubscription<List<CaseMessage>>? _messageSubscription;
  StreamSubscription<List<SupportTicket>>? _ticketSubscription;

  SupportTicket? _ticket;
  List<CaseMessage>? _messages;
  String? _pendingBody;
  Set<String> _idsBeforeSend = const {};
  bool _sendConfirmed = false;
  String? _error;
  bool _sending = false;
  bool _connected = false;
  bool _streamFailed = false;
  bool _reopening = false;
  int _messageRevision = 0;

  ParticipantSupportConversationRepository? get _conversations {
    final repository = widget.repository;
    return repository is ParticipantSupportConversationRepository
        ? repository as ParticipantSupportConversationRepository
        : null;
  }

  @override
  void initState() {
    super.initState();
    _attachments =
        widget.attachmentDraft ??
        SupportChatAttachmentDraft(contextId: widget.orderId);
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
            _messageRevision++;
            setState(() {
              _receiveMessages(messages);
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
            if (mounted) {
              setState(() {
                _connected = false;
                _streamFailed = true;
              });
            }
          },
        );

    final revision = ++_messageRevision;
    try {
      final messages = await conversations.fetchMessages(ticket.id);
      if (!mounted ||
          _ticket?.id != ticket.id ||
          revision != _messageRevision) {
        return;
      }
      setState(() {
        _receiveMessages(messages);
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted || revision != _messageRevision) return;
      setState(() {
        _messages ??= const [];
        _streamFailed = true;
        _error = 'Chưa đồng bộ được tin nhắn. Chạm trạng thái để thử lại.';
      });
    }
  }

  void _receiveMessages(List<CaseMessage> messages) {
    _messages = messages;
    // Realtime có thể xác nhận trước khi HTTP trả về. Thay tin đang gửi,
    // chỉ đối chiếu ID mới để giữ những lần gửi cùng nội dung có chủ ý.
    if (_pendingBody != null &&
        messages.any(
          (message) =>
              message.senderId == widget.requesterId &&
              message.body == _pendingBody &&
              !_idsBeforeSend.contains(message.id),
        )) {
      _pendingBody = null;
      _sendConfirmed = true;
    }
  }

  void _watchTicket() {
    final repository = widget.repository;
    final ticketId = _ticket?.id;
    if (ticketId == null) return;
    if (repository is! ParticipantSupportDetailRepository &&
        widget.orderId.isEmpty) {
      return;
    }
    final stream = repository is ParticipantSupportDetailRepository
        ? (repository as ParticipantSupportDetailRepository).watchTicket(
            ticketId,
          )
        : repository.watchForOrder(widget.orderId);
    unawaited(_ticketSubscription?.cancel());
    _ticketSubscription = stream.listen(
      (tickets) {
        final currentId = _ticket?.id;
        if (!mounted || currentId == null) return;
        for (final ticket in tickets) {
          if (ticket.id == currentId) {
            setState(() => _ticket = ticket);
            break;
          }
        }
      },
      onError: (_) {
        if (mounted) {
          setState(
            () => _error =
                'Chưa đồng bộ được trạng thái yêu cầu. Hãy mở lại hội thoại.',
          );
        }
      },
    );
  }

  Future<void> _pickImages() async {
    if (_sending || _selectingImages) return;
    setState(() {
      _selectingImages = true;
      _error = null;
    });
    try {
      await _attachments.pick();
    } on R2MediaException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Không thể mở ảnh. Hãy kiểm tra quyền truy cập ảnh và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _selectingImages = false);
    }
  }

  Future<void> _send() async {
    var body = _composerController.text.trim();
    if (_sending || _selectingImages) return;
    if (body.isEmpty) {
      if (_attachments.images.isEmpty) return;
      body = CaseMessageContent.imageLabel;
    }
    if (widget.requesterRole != 'driver' &&
        _reopening &&
        (body.length < 3 || body.length > 3900)) {
      setState(() => _error = 'Nêu vấn đề cần hỗ trợ tiếp bằng 3–3900 ký tự.');
      return;
    }
    if (widget.requesterRole != 'driver' &&
        _ticket == null &&
        body.length < 10) {
      setState(() {
        _error = 'Hãy mô tả vấn đề rõ hơn bằng ít nhất 10 ký tự.';
      });
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _idsBeforeSend = {
        for (final message in _messages ?? <CaseMessage>[]) message.id,
      };
      _sendConfirmed = false;
    });

    try {
      final images = await _attachments.upload();
      if (!mounted) return;
      body = CaseMessageContent(text: body, images: images).encode();
      final maxLength = _reopening ? 3900 : 4000;
      if (widget.requesterRole != 'driver' && body.length > maxLength) {
        throw const CustomerSupportTicketException(
          'Tin nhắn kèm ảnh quá dài. Hãy rút gọn nội dung hoặc bớt ảnh.',
        );
      }
      setState(() => _pendingBody = body);
      _composerController.clear();
      _scrollToBottom();
      if (_reopening && _ticket != null) {
        final repository = widget.repository;
        if (repository is! ParticipantSupportReopenRepository) return;
        final ticket = await (repository as ParticipantSupportReopenRepository)
            .reopen(_ticket!.id, body);
        if (!mounted) return;
        setState(() {
          _ticket = ticket;
          _reopening = false;
          _pendingBody = null;
        });
        await _connectToTicket();
      } else if (_ticket == null) {
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
          _messages = _conversations != null
              ? null
              : [
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
        final revision = ++_messageRevision;
        try {
          final messages = await conversations.fetchMessages(_ticket!.id);
          if (mounted && revision == _messageRevision) {
            setState(() => _messages = messages);
          }
        } catch (_) {
          if (mounted) {
            setState(
              () => _error =
                  'Tin nhắn đã gửi. Chưa tải được hội thoại mới nhất; hãy tải lại.',
            );
          }
        }
      }
      if (mounted) setState(_attachments.clear);
      _scrollToBottom();
    } on R2MediaException catch (error) {
      _restoreFailedMessage(body, 'Chưa tải được ảnh: ${error.message}');
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
      if (_sendConfirmed) {
        _attachments.clear();
        _error = 'Tin nhắn đã gửi. Hãy tải lại để đồng bộ hội thoại.';
        return;
      }
      _error = message;
      if (_composerController.text.isEmpty) {
        final text = CaseMessageContent.decode(body).text;
        _composerController.text = text;
        _composerController.selection = TextSelection.collapsed(
          offset: text.length,
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
    if (_ticket == null) return 'Gửi yêu cầu để CSKH tiếp nhận';
    if (_streamFailed) return 'Mất kết nối · Chạm để thử lại';
    if (_connected) return 'Đã đồng bộ hội thoại';
    return 'Đang chờ cập nhật · Chạm để tải lại';
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
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                SupportChatHeader(
                  compact: keyboard > 0 || constraints.maxHeight < 420,
                  connectionLabel: _connectionLabel,
                  connected: !_streamFailed && _connected,
                  orderLabel: _orderLabel,
                  subject: widget.subject,
                  showSubject: widget.requesterRole != 'driver',
                  statusLabel: statusLabel,
                  statusColor: statusColor,
                  onClose: _close,
                  onRetry: ticket != null
                      ? () => unawaited(_connectToTicket())
                      : null,
                ),
                Expanded(
                  child: SupportChatMessages(
                    messages: _messages,
                    requesterId: widget.requesterId,
                    scrollController: _scrollController,
                    pendingBody: _pendingBody,
                    guidance: ticket == null && widget.requesterRole != 'driver'
                        ? SupportIssue.fromSubject(
                            widget.subject,
                          ).participantHint
                        : null,
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight / 2,
                  ),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: SupportChatComposer(
                      controller: _composerController,
                      sending: _sending || _selectingImages,
                      started: ticket != null,
                      closed: !_reopening && (ticket?.status.isClosed ?? false),
                      onReopen:
                          widget.repository
                              is ParticipantSupportReopenRepository
                          ? () => setState(() => _reopening = true)
                          : null,
                      error: _error,
                      unrestricted: widget.requesterRole == 'driver',
                      onSend: _send,
                      onAttach: _pickImages,
                      attachmentPreview: _attachments.images.isEmpty
                          ? null
                          : SupportChatAttachmentPreview(
                              images: _attachments.images,
                              enabled: !_sending && !_selectingImages,
                              onRemove: (image) =>
                                  setState(() => _attachments.remove(image)),
                            ),
                    ),
                  ),
                ),
                if (_reopening)
                  TextButton(
                    onPressed: _sending
                        ? null
                        : () => setState(() => _reopening = false),
                    child: const Text('Hủy mở lại yêu cầu'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
