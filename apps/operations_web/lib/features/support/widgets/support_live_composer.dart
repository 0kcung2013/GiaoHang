import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/support_ticket.dart';
import '../constants/support_ticket_strings.dart';

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
    decoration: BoxDecoration(
      color: visibility == CaseMessageVisibility.internal
          ? AppColors.warning.withValues(alpha: .06)
          : AppColors.bgCard,
    ),
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
              label: SupportTicketStrings.replyTo(recipientLabel),
              selected: visibility == CaseMessageVisibility.public,
              onTap: () => onVisibilityChanged(CaseMessageVisibility.public),
            ),
            _VisibilityChip(
              icon: Icons.lock_outline_rounded,
              label: SupportTicketStrings.internalNote,
              tone: AppColors.warning,
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
              label: const Text(SupportTicketStrings.useReplyTemplate),
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
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: visibility == CaseMessageVisibility.internal
                      ? SupportTicketStrings.internalHint
                      : SupportTicketStrings.replyHint,
                  counterText: '',
                  errorText: error,
                  filled: true,
                  fillColor: AppColors.bgLight,
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.md,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.md,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.md,
                    borderSide: BorderSide(
                      color: AppColors.borderFocus,
                      width: 1.5,
                    ),
                  ),
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
                  ? SupportTicketStrings.saveInternalNote
                  : SupportTicketStrings.sendReply,
              onPressed: sending ? null : onSend,
              style: IconButton.styleFrom(
                minimumSize: const Size(AppSpacing.xl5, AppSpacing.xl5),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAccent,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
              ),
              icon: sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnAccent,
                      ),
                    )
                  : Icon(
                      visibility == CaseMessageVisibility.internal
                          ? Icons.note_add_rounded
                          : Icons.arrow_upward_rounded,
                    ),
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
    this.tone = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? tone.withValues(alpha: .08) : Colors.transparent,
      borderRadius: AppRadius.sm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.sm,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.sm,
            border: Border.all(
              color: selected ? tone.withValues(alpha: .35) : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
