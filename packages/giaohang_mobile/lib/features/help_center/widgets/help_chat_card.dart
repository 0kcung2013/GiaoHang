import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../help_center_strings.dart';

class HelpChatCard extends StatelessWidget {
  const HelpChatCard({required this.onChat, super.key});
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: AppColors.bgWarm,
      borderRadius: AppRadius.xl,
      border: Border.all(color: AppColors.accentLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.lg,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                HelpCenterStrings.chatTitle,
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          HelpCenterStrings.chatHint,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          key: const Key('help-center-chat'),
          onPressed: onChat,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.textOnAccent,
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.all(AppSpacing.md),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            textStyle: AppTextStyles.labelLarge,
          ),
          icon: const Icon(Icons.forum_rounded, size: 20),
          label: const Text(HelpCenterStrings.chat),
        ),
      ],
    ),
  );
}
