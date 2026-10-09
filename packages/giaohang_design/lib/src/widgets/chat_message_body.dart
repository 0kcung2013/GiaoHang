import 'package:flutter/material.dart';

import '../app_theme.dart';

typedef ChatImageBuilder = Widget Function(String storedValue, BoxFit fit);

class ChatMessageBody extends StatelessWidget {
  const ChatMessageBody({
    required this.text,
    required this.images,
    required this.imageBuilder,
    this.textStyle,
    super.key,
  });

  final String text;
  final List<String> images;
  final ChatImageBuilder imageBuilder;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (text.isNotEmpty)
        Text(text, style: textStyle ?? AppTextStyles.bodyMedium),
      if (images.isNotEmpty) ...[
        if (text.isNotEmpty) const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var index = 0; index < images.length; index++)
              Semantics(
                label: 'Xem ảnh đính kèm ${index + 1}',
                button: true,
                child: Material(
                  color: AppColors.bgLight,
                  borderRadius: AppRadius.md,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('chat-image-$index'),
                    onTap: () => _openImage(context, images[index]),
                    child: SizedBox.square(
                      dimension: 88,
                      child: imageBuilder(images[index], BoxFit.cover),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ],
  );

  void _openImage(BuildContext context, String value) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: AppColors.bgDark,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Đóng ảnh',
                  color: AppColors.textOnDark,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: SizedBox.expand(
                    child: imageBuilder(value, BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
