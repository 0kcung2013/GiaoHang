import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/risk_report.dart';
import '../constants/risk_report_strings.dart';
import '../utils/risk_report_ui.dart';

typedef RiskMessageSender =
    Future<void> Function(String body, CaseMessageVisibility visibility);

class RiskCaseConversation extends StatefulWidget {
  const RiskCaseConversation({
    required this.messages,
    required this.currentUserId,
    required this.canReply,
    required this.onSend,
    this.publicRecipient = 'người báo cáo',
    this.allowInternal = true,
    super.key,
  });

  final List<CaseMessage>? messages;
  final String currentUserId;
  final bool canReply;
  final RiskMessageSender onSend;
  final String? publicRecipient;
  final bool allowInternal;

  @override
  State<RiskCaseConversation> createState() => _RiskCaseConversationState();
}

class _RiskCaseConversationState extends State<RiskCaseConversation> {
  final _controller = TextEditingController();
  CaseMessageVisibility _visibility = CaseMessageVisibility.public;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.publicRecipient == null) {
      _visibility = CaseMessageVisibility.internal;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Vui lòng nhập nội dung phản hồi.');
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
          Row(
            children: [
              const Icon(Icons.forum_outlined, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.allowInternal
                      ? 'Trao đổi hồ sơ'
                      : 'Trao đổi với ${widget.publicRecipient}',
                  style: AppTextStyles.headingSmall,
                ),
              ),
              Text(
                '${widget.messages?.length ?? 0} tin',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.messages == null)
            const Center(child: CircularProgressIndicator())
          else if (widget.messages!.isEmpty)
            Text(
              'Chưa có trao đổi trong hồ sơ này.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            ...widget.messages!.map(
              (message) => _MessageBubble(
                message: message,
                mine: message.senderId == widget.currentUserId,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (!widget.canReply)
            Text(
              widget.allowInternal
                  ? 'Nhận hồ sơ hoặc dùng quyền tiếp quản Admin trước khi phản hồi.'
                  : RiskReportStrings.acceptBeforeReply,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            if (widget.publicRecipient != null && widget.allowInternal)
              SegmentedButton<CaseMessageVisibility>(
                segments: [
                  ButtonSegment(
                    value: CaseMessageVisibility.public,
                    icon: Icon(Icons.person_outline_rounded),
                    label: Text('Gửi ${widget.publicRecipient}'),
                  ),
                  const ButtonSegment(
                    value: CaseMessageVisibility.internal,
                    icon: Icon(Icons.lock_outline_rounded),
                    label: Text('Nội bộ'),
                  ),
                ],
                selected: {_visibility},
                onSelectionChanged: _sending
                    ? null
                    : (values) => setState(() => _visibility = values.first),
              ),
            if (widget.publicRecipient == null)
              Text(
                'Ghi chú nội bộ. Trao đổi với khách/tài xế qua yêu cầu liên quan.',
                style: AppTextStyles.bodySmall,
              ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('risk-case-message-field'),
              controller: _controller,
              minLines: 2,
              maxLines: 5,
              maxLength: 4000,
              decoration: InputDecoration(
                hintText: _visibility == CaseMessageVisibility.internal
                    ? 'Ghi chú chỉ Support/Admin nhìn thấy'
                    : 'Cập nhật tiến độ hoặc yêu cầu thêm thông tin',
                errorText: _error,
                filled: true,
                fillColor: AppColors.bgCard,
                border: const OutlineInputBorder(borderRadius: AppRadius.md),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('send-risk-case-message'),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Gửi phản hồi'),
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
    final color = message.isInternal ? AppColors.warning : AppColors.accent;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: mine ? 0.12 : 0.07),
          borderRadius: AppRadius.md,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _roleLabel(message.senderRole),
                  style: AppTextStyles.labelSmall.copyWith(color: color),
                ),
                if (message.isInternal) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.lock_outline_rounded, size: 14),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(message.body, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              RiskReportUi.formatDateTime(message.createdAt),
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

String _roleLabel(String role) => switch (role) {
  'customer' => 'Khách hàng',
  'driver' => 'Tài xế',
  'support' => 'CSKH',
  'admin' => 'Admin',
  _ => 'Hệ thống',
};
