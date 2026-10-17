import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_contact_message.dart';
import '../order_contact_strings.dart';
import '../services/order_message_alert_transport.dart';
import 'order_incoming_message_button.dart';

class DriverIncomingMessageAlert extends StatefulWidget {
  const DriverIncomingMessageAlert({
    super.key,
    required this.orderId,
    required this.currentUserId,
    required this.onOpenChat,
    this.transport,
  });

  final String orderId;
  final String currentUserId;
  final Future<void> Function() onOpenChat;
  final OrderMessageAlertTransport? transport;

  @override
  State<DriverIncomingMessageAlert> createState() =>
      _DriverIncomingMessageAlertState();
}

class _DriverIncomingMessageAlertState
    extends State<DriverIncomingMessageAlert> {
  late final OrderMessageAlertTransport _transport;
  final Set<String> _receivedMessageIds = <String>{};
  int _unreadCount = 0;
  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _transport =
        widget.transport ??
        SupabaseOrderMessageAlertTransport(
          client: Supabase.instance.client,
          currentUserId: widget.currentUserId,
        );
    unawaited(_connect());
  }

  Future<void> _connect() async {
    try {
      await _transport.connect(onMessage: _handleMessage);
    } catch (error) {
      debugPrint('[DriverMessageAlert] Cannot connect: $error');
    }
  }

  void _handleMessage(OrderContactMessage message) {
    if (!mounted ||
        message.orderId != widget.orderId ||
        message.senderId == widget.currentUserId ||
        !_receivedMessageIds.add(message.id)) {
      return;
    }
    setState(() => _unreadCount++);
  }

  Future<void> _openChat() async {
    if (_openingChat || _unreadCount == 0) return;
    setState(() {
      _openingChat = true;
      _unreadCount = 0;
    });
    try {
      await widget.onOpenChat();
    } finally {
      if (mounted) {
        setState(() {
          _openingChat = false;
          _unreadCount = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_transport.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unreadCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: OrderIncomingMessageButton(
        buttonKey: const Key('driver-incoming-message-button'),
        unreadCount: _unreadCount,
        onPressed: _openChat,
        semanticLabel: OrderContactStrings.driverUnreadMessages(_unreadCount),
        tooltip: OrderContactStrings.viewNewMessages,
      ),
    );
  }
}
