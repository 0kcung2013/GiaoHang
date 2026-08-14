import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../utils/order_help_ui.dart';

class OrderHelpConversation extends StatefulWidget {
  const OrderHelpConversation({
    required this.messages,
    required this.onSend,
    super.key,
  });

  final List<CaseMessage>? messages;
  final Future<void> Function(String body)? onSend;

  @override
  State<OrderHelpConversation> createState() => _OrderHelpConversationState();
}

class _OrderHelpConversationState extends State<OrderHelpConversation> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || widget.onSend == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend!(body);
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
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Trao đổi với CSKH', style: AppTextStyles.headingSmall),
          const SizedBox(height: AppSpacing.md),
          if (widget.messages == null)
            const Center(child: CircularProgressIndicator())
          else if (widget.messages!.isEmpty)
            Text(
              'CSKH chưa gửi thêm phản hồi.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            for (final message in widget.messages!)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: message.senderRole == 'customer'
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : AppColors.bgLight,
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.senderRole == 'customer' ? 'Bạn' : 'CSKH',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(message.body, style: AppTextStyles.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      OrderHelpUi.dateTime(message.createdAt),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          if (widget.onSend != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('order-help-reply-field'),
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              maxLength: 4000,
              decoration: InputDecoration(
                hintText: 'Bổ sung thông tin cho CSKH',
                errorText: _error,
                filled: true,
                fillColor: AppColors.bgLight,
                border: const OutlineInputBorder(borderRadius: AppRadius.md),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('send-order-help-reply'),
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
