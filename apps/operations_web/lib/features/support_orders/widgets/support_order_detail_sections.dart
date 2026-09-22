import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../data/support_order_repository.dart';
import '../models/support_order.dart';
import '../utils/support_order_ui.dart';

class SupportOrderContactBlock extends StatelessWidget {
  const SupportOrderContactBlock({
    required this.title,
    this.name,
    this.phone,
    super.key,
  });

  final String title;
  final String? name;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final contactName = name?.trim().isNotEmpty == true
        ? name!
        : 'Chưa cập nhật';
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Text(
            contactName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (phone?.trim().isNotEmpty == true)
            SelectableText(
              phone!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class SupportOrderFact extends StatelessWidget {
  const SupportOrderFact({required this.label, this.value, super.key});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Text(
            value?.trim().isNotEmpty == true ? value! : 'Chưa cập nhật',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class SupportOrderTimelineHistory extends StatelessWidget {
  const SupportOrderTimelineHistory({
    required this.orderId,
    required this.repository,
    super.key,
  });

  final String orderId;
  final SupportOrderRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupportOrderStatusLog>>(
      future: repository.fetchStatusLogs(orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _TimelineLoading();
        }
        if (snapshot.hasError) {
          return Text(
            'Không thể tải lịch sử trạng thái.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          );
        }
        final logs = snapshot.data ?? const [];
        if (logs.isEmpty) {
          return Text(
            'Đơn hàng chưa có nhật ký trạng thái.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          );
        }
        return Column(
          children: [
            for (var index = 0; index < logs.length; index++)
              _TimelineItem(log: logs[index], isLast: index == logs.length - 1),
          ],
        );
      },
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.log, required this.isLast});

  final SupportOrderStatusLog log;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = SupportOrderUi.statusColor(log.status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(Icons.check_circle_rounded, size: 18, color: color),
            if (!isLast)
              Container(width: 2, height: 42, color: AppColors.border),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title?.trim().isNotEmpty == true
                      ? log.title!
                      : SupportOrderUi.statusLabel(log.status),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  SupportOrderUi.formatDateTime(log.createdAt),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                if (log.description?.trim().isNotEmpty == true)
                  Text(
                    log.description!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineLoading extends StatelessWidget {
  const _TimelineLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 18,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: const BoxDecoration(
            color: AppColors.border,
            borderRadius: AppRadius.sm,
          ),
        ),
      ),
    );
  }
}
