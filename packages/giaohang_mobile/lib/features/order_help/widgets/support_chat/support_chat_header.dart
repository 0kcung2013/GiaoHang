import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class SupportChatHeader extends StatelessWidget {
  const SupportChatHeader({
    required this.connectionLabel,
    required this.connected,
    required this.orderLabel,
    required this.subject,
    required this.statusLabel,
    required this.statusColor,
    required this.onClose,
    this.onRetry,
    this.showSubject = true,
    this.compact = false,
    this.title = 'CSKH GiaoHang',
    super.key,
  });

  final String connectionLabel;
  final bool connected;
  final String orderLabel;
  final String subject;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onClose;
  final VoidCallback? onRetry;
  final bool showSubject;
  final bool compact;
  final String title;

  Widget _orderSummary() => Row(
    children: [
      if (showSubject) ...[
        Container(
          width: AppSpacing.xl4,
          height: AppSpacing.xl4,
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.md,
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: orderLabel,
              child: Text(
                orderLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mono.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (showSubject) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _statusBadge() => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: statusColor.withValues(alpha: 0.1),
      borderRadius: AppRadius.full,
    ),
    child: Text(
      statusLabel,
      style: AppTextStyles.labelSmall.copyWith(color: statusColor),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              width: AppSpacing.xl4,
              height: AppSpacing.xs,
              decoration: const BoxDecoration(
                color: AppColors.border,
                borderRadius: AppRadius.full,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: AppSpacing.xl5,
                      height: AppSpacing.xl5,
                      decoration: const BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: AppRadius.md,
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: AppColors.accent,
                        size: 26,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: AppSpacing.md,
                        height: AppSpacing.md,
                        decoration: BoxDecoration(
                          color: connected
                              ? AppColors.success
                              : AppColors.warning,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bgCard, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.headingSmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      InkWell(
                        onTap: onRetry,
                        borderRadius: AppRadius.sm,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            connectionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: connected
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng cuộc trò chuyện',
                  onPressed: onClose,
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.xl5,
                    minHeight: AppSpacing.xl5,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (!compact)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: AppColors.bgWarm,
                border: Border(
                  top: BorderSide(color: AppColors.border),
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow =
                      constraints.maxWidth <
                      320 * MediaQuery.textScalerOf(context).scale(1);
                  return narrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _orderSummary(),
                            const SizedBox(height: AppSpacing.sm),
                            _statusBadge(),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: _orderSummary()),
                            const SizedBox(width: AppSpacing.sm),
                            _statusBadge(),
                          ],
                        );
                },
              ),
            ),
        ],
      ),
    );
  }
}
