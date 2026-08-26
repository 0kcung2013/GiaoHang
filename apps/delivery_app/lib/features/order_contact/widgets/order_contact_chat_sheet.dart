import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_contact_message.dart';
import '../services/order_contact_transport.dart';
import '../utils/order_contact_time_formatter.dart';

part 'order_contact_chat_components.dart';

Future<void> showOrderContactChatSheet({
  required BuildContext context,
  required String orderId,
  required String currentUserId,
  required OrderContactSenderRole currentRole,
  required String counterpartName,
  required OrderContactStage stage,
}) {
  final transport = SupabaseOrderContactTransport(
    client: Supabase.instance.client,
    orderId: orderId,
    currentUserId: currentUserId,
  );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => OrderContactChatSheet(
      orderId: orderId,
      currentUserId: currentUserId,
      currentRole: currentRole,
      counterpartName: counterpartName,
      stage: stage,
      transport: transport,
    ),
  );
}

class OrderContactChatSheet extends StatefulWidget {
  const OrderContactChatSheet({
    super.key,
    required this.orderId,
    required this.currentUserId,
    required this.currentRole,
    required this.counterpartName,
    required this.stage,
    required this.transport,
  });

  final String orderId;
  final String currentUserId;
  final OrderContactSenderRole currentRole;
  final String counterpartName;
  final OrderContactStage stage;
  final OrderContactTransport transport;

  @override
  State<OrderContactChatSheet> createState() => _OrderContactChatSheetState();
}

class _OrderContactChatSheetState extends State<OrderContactChatSheet> {
  final _controller = TextEditingController();
  final _messages = <OrderContactMessage>[];
  bool _connected = false;
  bool _connectionFailed = false;
  bool _sending = false;
  bool _canSend = true;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final conversation = await widget.transport.loadConversation();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(conversation.messages);
        _canSend = conversation.canSend;
      });
      if (_messages.isNotEmpty) {
        unawaited(widget.transport.markRead(_messages.last.id));
      }
      await _connect();
    } catch (_) {
      if (mounted) setState(() => _connectionFailed = true);
    }
  }

  Future<void> _connect() async {
    try {
      await widget.transport.connect(
        onMessage: (message) {
          if (!mounted ||
              _messages.any(
                (item) =>
                    item.id == message.id ||
                    item.clientMessageId == message.clientMessageId,
              )) {
            return;
          }
          setState(() {
            _messages.add(message);
            _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
          });
          unawaited(widget.transport.markRead(message.id));
        },
        onConnectionChanged: (connected) {
          if (!mounted) return;
          setState(() {
            _connected = connected;
            if (connected) _connectionFailed = false;
          });
        },
      );
    } catch (_) {
      if (mounted) setState(() => _connectionFailed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    unawaited(widget.transport.close());
    super.dispose();
  }

  Future<void> _send(String rawBody, OrderContactMessageKind kind) async {
    final body = rawBody.trim();
    if (body.isEmpty || _sending || !_connected) return;
    final message = OrderContactMessage.createPending(
      orderId: widget.orderId,
      senderId: widget.currentUserId,
      senderRole: widget.currentRole,
      body: body,
      sentAt: DateTime.now().toUtc(),
      kind: kind,
    );
    final clientMessageId = message.clientMessageId;
    setState(() {
      _sending = true;
      _messages.add(message);
    });
    _controller.clear();
    try {
      final saved = await widget.transport.send(message);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere(
          (item) => item.clientMessageId == clientMessageId,
        );
        if (index >= 0) _messages[index] = saved;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((item) => item.id == message.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa gửi được tin nhắn. Vui lòng thử lại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<String> get _quickMessages {
    if (widget.currentRole == OrderContactSenderRole.customer) {
      return const [
        'Tôi xuống ngay ạ.',
        'Vui lòng chờ tôi 2 phút.',
        'Bạn đang đứng ở vị trí nào?',
      ];
    }
    return switch (widget.stage) {
      OrderContactStage.pickup => const [
        'Tôi đã đến điểm lấy hàng.',
        'Vui lòng mang hàng ra giúp tôi.',
        'Tôi đang chờ tại cổng.',
      ],
      OrderContactStage.delivery => const [
        'Tôi đã đến điểm giao hàng.',
        'Vui lòng ra nhận hàng giúp tôi.',
        'Tôi đang chờ tại cổng.',
      ],
      OrderContactStage.general => const [
        'Tôi đã đến nơi.',
        'Vui lòng kiểm tra tin nhắn.',
        'Tôi đang chờ tại cổng.',
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _ChatHeader(
              counterpartName: widget.counterpartName,
              connected: _connected,
              connectionFailed: _connectionFailed,
              onClose: () => Navigator.pop(context),
            ),
            Expanded(
              child: _MessageList(
                messages: _messages,
                currentUserId: widget.currentUserId,
              ),
            ),
            if (_canSend) ...[
              _QuickMessages(
                messages: _quickMessages,
                enabled: _connected && !_sending,
                onSend: (body) =>
                    _send(body, OrderContactMessageKind.quickReply),
              ),
              _MessageComposer(
                controller: _controller,
                enabled: _connected && !_sending,
                onSend: () =>
                    _send(_controller.text, OrderContactMessageKind.text),
              ),
            ] else
              const _ReadOnlyConversationNotice(),
          ],
        ),
      ),
    );
  }
}
