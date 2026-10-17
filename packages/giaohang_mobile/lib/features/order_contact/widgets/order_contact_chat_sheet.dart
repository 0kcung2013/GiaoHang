import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_contact_message.dart';
import '../models/order_contact_timeline.dart';
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
  final _timeline = OrderContactTimeline();
  Timer? _syncTimer;
  bool _refreshInFlight = false;
  bool _hasLoadedConversation = false;
  String? _lastReadMessageId;
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
    // Register realtime before starting the history read, then catch up once
    // the channel joins. A message sent between those steps is never erased.
    final connecting = _connect();
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshConversation());
    });
    await _refreshConversation();
    await connecting;
    if (mounted && _connected) await _refreshConversation();
  }

  Future<void> _refreshConversation() async {
    if (!mounted || _refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final conversation = await widget.transport.loadConversation();
      if (!mounted) return;
      setState(() {
        _timeline.merge(conversation.messages);
        _canSend = conversation.canSend;
        _hasLoadedConversation = true;
        if (_connected) _connectionFailed = false;
      });
      unawaited(_markLatestRead());
    } catch (_) {
      if (mounted && !_hasLoadedConversation) {
        setState(() => _connectionFailed = true);
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _markLatestRead() async {
    final message = _timeline.latestPersisted;
    if (message == null || message.id == _lastReadMessageId) return;
    _lastReadMessageId = message.id;
    try {
      await widget.transport.markRead(message.id);
    } catch (_) {
      if (_lastReadMessageId == message.id) _lastReadMessageId = null;
    }
  }

  Future<void> _connect() async {
    try {
      await widget.transport.connect(
        onMessage: (message) {
          if (!mounted || message.orderId != widget.orderId) {
            return;
          }
          setState(() => _timeline.merge([message]));
          unawaited(_markLatestRead());
        },
        onConnectionChanged: (connected) {
          if (!mounted) return;
          setState(() {
            _connected = connected;
            if (connected) _connectionFailed = false;
          });
          if (connected && _hasLoadedConversation) {
            unawaited(_refreshConversation());
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _connectionFailed = true);
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
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
      _timeline.merge([message]);
    });
    _controller.clear();
    try {
      final saved = await widget.transport.send(message);
      if (!mounted) return;
      setState(() => _timeline.merge([saved]));
    } catch (_) {
      if (!mounted) return;
      if (_timeline.hasPersisted(
        clientMessageId: clientMessageId,
        senderId: widget.currentUserId,
      )) {
        return;
      }
      setState(() => _timeline.removePending(clientMessageId));
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
                messages: _timeline.messages,
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
