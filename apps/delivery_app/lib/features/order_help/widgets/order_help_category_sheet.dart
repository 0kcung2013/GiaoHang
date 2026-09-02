import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/order_help_option.dart';
import '../order_help_strings.dart';

Future<OrderHelpOption?> showOrderHelpCategorySheet(BuildContext context) {
  return showModalBottomSheet<OrderHelpOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.primary.withValues(alpha: 0.42),
    builder: (_) => const _OrderHelpCategorySheet(),
  );
}

class _OrderHelpCategorySheet extends StatelessWidget {
  const _OrderHelpCategorySheet();

  @override
  Widget build(BuildContext context) {
    final supportOptions = customerOrderHelpOptions
        .where((option) => option.channel == OrderHelpChannel.support)
        .toList();
    final riskOptions = customerOrderHelpOptions
        .where((option) => option.channel == OrderHelpChannel.risk)
        .toList();
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppShadow.elevated,
        ),
        child: Column(
          children: [
            _Header(onClose: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.xl2,
                ),
                children: [
                  const _ChannelHeader(
                    icon: Icons.support_agent_rounded,
                    title: OrderHelpStrings.supportChannel,
                    subtitle: OrderHelpStrings.supportChannelHint,
                    color: AppColors.info,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final option in supportOptions) ...[
                    _OptionTile(
                      option: option,
                      onTap: () => Navigator.pop(context, option),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  const _ChannelHeader(
                    icon: Icons.report_problem_outlined,
                    title: OrderHelpStrings.reportChannel,
                    subtitle: OrderHelpStrings.reportChannelHint,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final option in riskOptions) ...[
                    _OptionTile(
                      option: option,
                      onTap: () => Navigator.pop(context, option),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.md,
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.headingSmall),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.full,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      OrderHelpStrings.chooseTitle,
                      style: AppTextStyles.headingLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      OrderHelpStrings.chooseSubtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: OrderHelpStrings.close,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.onTap});

  final OrderHelpOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgent = option.channel == OrderHelpChannel.risk;
    return Semantics(
      button: true,
      label: option.label,
      child: Material(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lg,
              border: Border.all(
                color: urgent
                    ? AppColors.warning.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
              boxShadow: AppShadow.subtle,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: urgent ? AppColors.accentLight : AppColors.bgLight,
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(
                    option.icon,
                    color: urgent ? AppColors.accent : AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.label, style: AppTextStyles.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        option.description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
