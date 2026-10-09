import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/support_ticket.dart';

class SupportLiveComposer extends StatelessWidget {
  const SupportLiveComposer({
    required this.controller,
    required this.visibility,
    required this.sending,
    required this.onVisibilityChanged,
    required this.onSend,
    this.error,
    this.recipientLabel = 'người yêu cầu',
    this.replyTemplate,
    super.key,
  });

  final TextEditingController controller;
  final CaseMessageVisibility visibility;
  final bool sending;
  final String? error;
  final String recipientLabel;
  final String? replyTemplate;
  final ValueChanged<CaseMessageVisibility> onVisibilityChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.bgCard,
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl2,
      AppSpacing.md,
      AppSpacing.xl2,
      AppSpacing.lg,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _VisibilityChip(
              icon: Icons.person_outline_rounded,
              label: 'Gửi $recipientLabel',
              selected: visibility == CaseMessageVisibility.public,
              onTap: () => onVisibilityChanged(CaseMessageVisibility.public),
            ),
            _VisibilityChip(
              icon: Icons.lock_outline_rounded,
              label: 'Ghi chú nội bộ',
              selected: visibility == CaseMessageVisibility.internal,
              onTap: () => onVisibilityChanged(CaseMessageVisibility.internal),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (replyTemplate != null && visibility == CaseMessageVisibility.public)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => TextButton.icon(
              onPressed: sending || value.text.isNotEmpty
                  ? null
                  : () {
                      controller.text = replyTemplate!;
                      controller.selection = TextSelection.collapsed(
                        offset: controller.text.length,
                      );
                    },
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Dùng mẫu trả lời · sửa trước khi gửi'),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('support-case-message-field'),
                controller: controller,
                enabled: !sending,
                minLines: 1,
                maxLines: 3,
                maxLength: 4000,
                decoration: InputDecoration(
                  hintText: visibility == CaseMessageVisibility.internal
                      ? 'Nội dung chỉ CSKH và Admin nhìn thấy'
                      : 'Nhập tin nhắn cho người dùng...',
                  counterText: '',
                  errorText: error,
                  filled: true,
                  fillColor: AppColors.bgLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              key: const Key('send-support-case-message'),
              tooltip: visibility == CaseMessageVisibility.internal
                  ? 'Lưu ghi chú nội bộ'
                  : 'Gửi phản hồi',
              onPressed: sending ? null : onSend,
              style: IconButton.styleFrom(
                minimumSize: const Size(AppSpacing.xl5, AppSpacing.xl5),
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
              ),
              icon: sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnAccent,
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ],
    ),
  );
}

class SupportReplyLocked extends StatelessWidget {
  const SupportReplyLocked({
    this.message = 'Nhận xử lý hồ sơ để bắt đầu phản hồi',
    super.key,
  });
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.bgCard,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_person_outlined,
          size: 18,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.accentLight : Colors.transparent,
    borderRadius: AppRadius.full,
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadius.full,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: AppRadius.full,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
