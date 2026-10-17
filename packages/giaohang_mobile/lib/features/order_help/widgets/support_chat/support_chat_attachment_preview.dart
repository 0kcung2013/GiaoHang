import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../controllers/support_chat_attachment_draft.dart';

class SupportChatAttachmentPreview extends StatelessWidget {
  const SupportChatAttachmentPreview({
    required this.images,
    required this.enabled,
    required this.onRemove,
    super.key,
  });

  final List<SupportChatImageDraft> images;
  final bool enabled;
  final ValueChanged<SupportChatImageDraft> onRemove;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.viewInsetsOf(context).bottom > 0 ? 56.0 : 80.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        height: size,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) => SizedBox.square(
            dimension: size,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: AppRadius.md,
                    child: Image.memory(
                      images[index].bytes,
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      semanticLabel: 'Ảnh đính kèm ${index + 1}',
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton.filled(
                    key: ValueKey('remove-support-chat-image-$index'),
                    tooltip: 'Bỏ ảnh ${index + 1}',
                    onPressed: enabled ? () => onRemove(images[index]) : null,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.8),
                      foregroundColor: AppColors.textOnDark,
                      minimumSize: const Size.square(AppSpacing.xl5),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
