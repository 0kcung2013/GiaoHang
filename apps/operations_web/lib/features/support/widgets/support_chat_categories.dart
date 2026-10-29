import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../models/support_chat_category.dart';

class SupportChatCategories extends StatelessWidget {
  const SupportChatCategories({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final SupportChatCategory value;
  final ValueChanged<SupportChatCategory> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 500 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final children = [
        for (final category in SupportChatCategory.values)
          SizedBox(
            width: stacked ? constraints.maxWidth : null,
            child: Semantics(
              selected: value == category,
              child: OutlinedButton.icon(
                key: ValueKey('support-chat-${category.name}'),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  foregroundColor: value == category
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  backgroundColor: value == category
                      ? AppColors.bgLight
                      : AppColors.bgCard,
                  side: BorderSide(
                    color: value == category
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.md,
                  ),
                  textStyle: AppTextStyles.labelMedium,
                ),
                onPressed: () => onChanged(category),
                icon: Icon(
                  category == SupportChatCategory.general
                      ? Icons.forum_rounded
                      : Icons.inventory_2_outlined,
                ),
                label: Text(category.label),
              ),
            ),
          ),
      ];
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: children,
      );
    },
  );
}
