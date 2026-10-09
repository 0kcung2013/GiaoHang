import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../core/widgets/stored_media_image.dart';
import '../models/support_ticket.dart';
import '../utils/support_ticket_ui.dart';

class SupportLiveMessages extends StatelessWidget {
  const SupportLiveMessages({
    required this.messages,
    required this.currentUserId,
    required this.scrollController,
    super.key,
  });

  final List<CaseMessage>? messages;
  final String currentUserId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final items = messages;
    return Column(
      children: [
        _Header(messageCount: items?.length),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: items == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : items.isEmpty
              ? const _Empty()
              : ListView.builder(
                  key: const Key('support-conversation-list'),
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl2,
                    AppSpacing.lg,
                    AppSpacing.xl2,
                    AppSpacing.xl2,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => Column(
                    children: [
                      if (_startsNewDay(items, index))
                        _DateDivider(date: items[index].createdAt),
                      _MessageBubble(
                        message: items[index],
                        mine: items[index].senderId == currentUserId,
                      ),
                      if (index < items.length - 1)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  static bool _startsNewDay(List<CaseMessage> messages, int index) {
    if (index == 0) return true;
    final current = messages[index].createdAt;
    final previous = messages[index - 1].createdAt;
    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.messageCount});

  final int? messageCount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xl2,
      vertical: AppSpacing.md,
    ),
    child: Row(
      children: [
        const Icon(
          Icons.forum_outlined,
          size: 20,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text('Hội thoại', style: AppTextStyles.headingSmall)),
        if (messageCount != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            '($messageCount)',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            'Lịch sử trao đổi',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final CaseMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    if (message.isInternal) return _InternalMessage(message: message);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              mine ? 'Bạn' : supportRoleLabel(message.senderRole),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: mine ? AppColors.accent : AppColors.bgCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(mine ? 14 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 14),
                ),
                border: mine ? null : Border.all(color: AppColors.border),
              ),
              child: _messageContent(
                message.body,
                AppTextStyles.bodyMedium.copyWith(
                  color: mine ? AppColors.textOnAccent : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
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

class _InternalMessage extends StatelessWidget {
  const _InternalMessage({required this.message});

  final CaseMessage message;

  @override
  Widget build(BuildContext context) => Align(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 17,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ghi chú nội bộ · ${supportRoleLabel(message.senderRole)}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _messageContent(message.body, AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _messageContent(String body, TextStyle style) {
  final content = CaseMessageContent.decode(body);
  return ChatMessageBody(
    text: content.text,
    images: content.images,
    textStyle: style,
    imageBuilder: (uri, fit) => StoredMediaImage(
      storedValue: uri,
      fit: fit,
      semanticLabel: 'Ảnh đính kèm',
      fallback: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textSecondary,
        ),
      ),
    ),
  );
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            _dateLabel(date),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.chat_bubble_outline_rounded,
          size: 30,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Chưa có tin nhắn',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

String supportRoleLabel(String role) => switch (role) {
  'customer' => 'Khách hàng',
  'driver' => 'Tài xế',
  'support' => 'CSKH',
  'admin' => 'Admin',
  _ => 'Người dùng',
};

String _dateLabel(DateTime date) {
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return 'Hôm nay';
  }
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
