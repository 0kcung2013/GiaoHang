import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../help_center_strings.dart';
import '../models/help_topic.dart';

class HelpTopicTile extends StatelessWidget {
  const HelpTopicTile({required this.topic, required this.onChat, super.key});

  final HelpTopic topic;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadius.lg,
      side: BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: PageStorageKey(topic.id),
      tilePadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: AppColors.accent,
      collapsedIconColor: AppColors.textSecondary,
      title: Text(
        topic.question,
        style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            topic.answer,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            HelpCenterStrings.stillNeedHelp,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onChat,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              textStyle: AppTextStyles.labelMedium,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.support_agent_rounded, size: 20),
            label: const Text(HelpCenterStrings.chat),
          ),
        ),
      ],
    ),
  );
}
