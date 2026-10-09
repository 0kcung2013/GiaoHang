import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class SupportChatComposer extends StatelessWidget {
  const SupportChatComposer({
    required this.controller,
    required this.sending,
    required this.started,
    required this.closed,
    required this.onSend,
    this.error,
    this.onReopen,
    this.unrestricted = false,
    this.onAttach,
    this.attachmentPreview,
    super.key,
  });

  final TextEditingController controller;
  final bool sending;
  final bool started;
  final bool closed;
  final String? error;
  final VoidCallback onSend;
  final VoidCallback? onReopen;
  final bool unrestricted;
  final VoidCallback? onAttach;
  final Widget? attachmentPreview;

  @override
  Widget build(BuildContext context) {
    if (closed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Cuộc trao đổi đã kết thúc',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (onReopen != null)
                TextButton(
                  onPressed: sending ? null : onReopen,
                  child: const Text('Vấn đề chưa được giải quyết'),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadow.subtle,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: AppDuration.fast,
              child: error == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xs,
                        0,
                        AppSpacing.xs,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 17,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              error!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (attachmentPreview != null) attachmentPreview!,
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (onAttach != null) ...[
                  IconButton(
                    key: const Key('attach-support-chat-image'),
                    tooltip: 'Đính kèm ảnh',
                    onPressed: sending ? null : onAttach,
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      minimumSize: const Size.square(AppSpacing.xl5),
                    ),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: TextField(
                    key: const Key('support-chat-composer'),
                    controller: controller,
                    enabled: !sending,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: unrestricted ? null : 4000,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintMaxLines: 1,
                      hintText: started || unrestricted
                          ? 'Nhập tin nhắn...'
                          : 'Mô tả vấn đề cần hỗ trợ...',
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.bgLight,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      border: const OutlineInputBorder(
                        borderRadius: AppRadius.lg,
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: AppRadius.lg,
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: AppRadius.lg,
                        borderSide: BorderSide(
                          color: AppColors.accent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  key: const Key('send-support-chat-message'),
                  tooltip: started ? 'Gửi tin nhắn' : 'Bắt đầu trao đổi',
                  onPressed: sending ? null : onSend,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(AppSpacing.xl5, AppSpacing.xl5),
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textOnAccent,
                    disabledBackgroundColor: AppColors.accentLight,
                    disabledForegroundColor: AppColors.accent,
                  ),
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
            if (!started && !unrestricted) ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  'Tin nhắn đầu tiên sẽ mở yêu cầu hỗ trợ cho đơn này.',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
