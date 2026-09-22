import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

class SupportChatMessages extends StatelessWidget {
  const SupportChatMessages({
    required this.messages,
    required this.requesterId,
    required this.scrollController,
    this.pendingBody,
    super.key,
  });

  final List<CaseMessage>? messages;
  final String requesterId;
  final ScrollController scrollController;
  final String? pendingBody;

  @override
  Widget build(BuildContext context) {
    final source = messages;
    final items = source == null
        ? null
        : ([...source]..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
    if (items == null) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: const [
          _ChatSkeleton(alignment: Alignment.centerLeft, width: 220),
          SizedBox(height: AppSpacing.md),
          _ChatSkeleton(alignment: Alignment.centerRight, width: 176),
          SizedBox(height: AppSpacing.md),
          _ChatSkeleton(alignment: Alignment.centerLeft, width: 192),
        ],
      );
    }

    return ListView(
      key: const Key('support-chat-message-list'),
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.xl2,
      ),
      children: [
        const _WelcomeMessage(),
        if (items.isNotEmpty) const SizedBox(height: AppSpacing.lg),
        for (var index = 0; index < items.length; index++) ...[
          if (_startsNewDay(items, index))
            _DateDivider(date: items[index].createdAt),
          _MessageBubble(
            message: items[index],
            mine: items[index].senderId == requesterId,
          ),
          if (index < items.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
        if ((pendingBody ?? '').isNotEmpty) ...[
          if (items.isNotEmpty) const SizedBox(height: AppSpacing.sm),
          _PendingMessageBubble(body: pendingBody!),
        ],
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

class _WelcomeMessage extends StatelessWidget {
  const _WelcomeMessage();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tin nhắn chào mừng từ CSKH',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _SupportAvatar(),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(5),
                ),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'GiaoHang đang ở đây để hỗ trợ. Bạn hãy mô tả vấn đề, '
                'CSKH sẽ phản hồi ngay trong cuộc trò chuyện.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xl4),
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
    final label = mine
        ? 'Bạn'
        : (message.senderName?.trim().isNotEmpty ?? false)
        ? message.senderName!
        : 'CSKH';
    return Semantics(
      label: '$label: ${message.body}',
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            const _SupportAvatar(),
            const SizedBox(width: AppSpacing.sm),
          ] else
            const SizedBox(width: AppSpacing.xl4),
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Text(
                    label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                    ),
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
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(mine ? 16 : 5),
                      bottomRight: Radius.circular(mine ? 5 : 16),
                    ),
                    border: mine ? null : Border.all(color: AppColors.border),
                    boxShadow: mine ? null : AppShadow.subtle,
                  ),
                  child: Text(
                    message.body,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: mine
                          ? AppColors.textOnAccent
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Text(
                    _timeLabel(message.createdAt),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (mine)
            const SizedBox(width: AppSpacing.sm)
          else
            const SizedBox(width: AppSpacing.xl4),
        ],
      ),
    );
  }
}

class _PendingMessageBubble extends StatelessWidget {
  const _PendingMessageBubble({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.72),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(5),
              ),
            ),
            child: Text(
              body,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textOnAccent,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Đang gửi...',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportAvatar extends StatelessWidget {
  const _SupportAvatar();

  @override
  Widget build(BuildContext context) => Container(
    width: AppSpacing.xl3,
    height: AppSpacing.xl3,
    decoration: const BoxDecoration(
      color: AppColors.accentLight,
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.support_agent_rounded,
      color: AppColors.accent,
      size: 18,
    ),
  );
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
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

class _ChatSkeleton extends StatelessWidget {
  const _ChatSkeleton({required this.alignment, required this.width});

  final Alignment alignment;
  final double width;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: Container(
      width: width,
      height: 58,
      decoration: const BoxDecoration(
        color: AppColors.border,
        borderRadius: AppRadius.lg,
      ),
    ),
  );
}

String _timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';

String _dateLabel(DateTime date) {
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return 'Hôm nay';
  }
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
