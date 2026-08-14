import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/support_ticket.dart';
import '../utils/support_ticket_ui.dart';

typedef SupportMessageSender =
    Future<void> Function(String body, CaseMessageVisibility visibility);

class SupportCaseConversation extends StatefulWidget {
  const SupportCaseConversation({
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
  State<SupportCaseConversation> createState() =>
      _SupportCaseConversationState();
}

class _SupportCaseConversationState extends State<SupportCaseConversation> {
  final _controller = TextEditingController();
  CaseMessageVisibility _visibility = CaseMessageVisibility.public;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
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
      if (mounted) _controller.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa gửi được phản hồi.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Trao đổi hồ sơ', style: AppTextStyles.headingSmall),
          const SizedBox(height: AppSpacing.md),
          if (widget.messages == null)
            const Center(child: CircularProgressIndicator())
          else if (widget.messages!.isEmpty)
            Text(
              'Chưa có trao đổi.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            for (final message in widget.messages!)
              _MessageBubble(
                message: message,
                mine: message.senderId == widget.currentUserId,
              ),
          const SizedBox(height: AppSpacing.md),
          if (!widget.canReply)
            Text(
              'Nhận xử lý hồ sơ trước khi gửi phản hồi.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            SegmentedButton<CaseMessageVisibility>(
              segments: const [
                ButtonSegment(
                  value: CaseMessageVisibility.public,
                  label: Text('Khách hàng'),
                  icon: Icon(Icons.person_outline_rounded),
                ),
                ButtonSegment(
                  value: CaseMessageVisibility.internal,
                  label: Text('Nội bộ'),
                  icon: Icon(Icons.lock_outline_rounded),
                ),
              ],
              selected: {_visibility},
              onSelectionChanged: (values) =>
                  setState(() => _visibility = values.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('support-case-message-field'),
              controller: _controller,
              minLines: 2,
              maxLines: 5,
              maxLength: 4000,
              decoration: InputDecoration(
                hintText: _visibility == CaseMessageVisibility.internal
                    ? 'Ghi chú chỉ Support/Admin nhìn thấy'
                    : 'Phản hồi hoặc yêu cầu khách bổ sung thông tin',
                errorText: _error,
                filled: true,
                fillColor: AppColors.bgCard,
                border: const OutlineInputBorder(borderRadius: AppRadius.md),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('send-support-case-message'),
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Đang gửi...' : 'Gửi phản hồi'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final CaseMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final color = message.isInternal ? AppColors.warning : AppColors.primary;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.md,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.isInternal
                  ? 'Nội bộ · ${message.senderRole}'
                  : message.senderRole,
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(message.body, style: AppTextStyles.bodySmall),
            Text(
              SupportTicketUi.dateTimeLabel(message.createdAt),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
