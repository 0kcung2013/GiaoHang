import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/support_ticket.dart';
import 'support_live_composer.dart';
import 'support_live_messages.dart';

typedef SupportMessageSender =
    Future<void> Function(String body, CaseMessageVisibility visibility);

class SupportLiveConversation extends StatefulWidget {
  const SupportLiveConversation({
    required this.messages,
    required this.currentUserId,
    required this.canReply,
    required this.onSend,
    super.key,
  });

  final List<CaseMessage>? messages;
  final String currentUserId;
  final bool canReply;
  final SupportMessageSender onSend;

  @override
  State<SupportLiveConversation> createState() =>
      _SupportLiveConversationState();
}

class _SupportLiveConversationState extends State<SupportLiveConversation> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  CaseMessageVisibility _visibility = CaseMessageVisibility.public;
  bool _sending = false;
  String? _error;

  List<CaseMessage>? get _messages {
    final source = widget.messages;
    if (source == null) return null;
    return [...source]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  void initState() {
    super.initState();
    _scrollToLatest(animate: false);
  }

  @override
  void didUpdateWidget(covariant SupportLiveConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_latestId(oldWidget.messages) != _latestId(widget.messages)) {
      _scrollToLatest();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Vui lòng nhập nội dung.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend(body, _visibility);
      if (!mounted) return;
      _controller.clear();
      _scrollToLatest();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa gửi được tin nhắn. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToLatest({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final offset = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          offset,
          duration: AppDuration.normal,
          curve: AppCurve.decelerate,
        );
      } else {
        _scrollController.jumpTo(offset);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgLight,
      child: Column(
        children: [
          Expanded(
            child: SupportLiveMessages(
              messages: _messages,
              currentUserId: widget.currentUserId,
              scrollController: _scrollController,
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (widget.canReply)
            SupportLiveComposer(
              controller: _controller,
              visibility: _visibility,
              sending: _sending,
              error: _error,
              onVisibilityChanged: (value) =>
                  setState(() => _visibility = value),
              onSend: _send,
            )
          else
            const SupportReplyLocked(),
        ],
      ),
    );
  }

  static String? _latestId(List<CaseMessage>? messages) {
    if (messages == null || messages.isEmpty) return null;
    final sorted = [...messages]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted.last.id;
  }
}
