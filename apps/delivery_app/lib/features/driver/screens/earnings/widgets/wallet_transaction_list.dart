import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../../../core/models/driver_wallet.dart';

class WalletTransactionList extends StatelessWidget {
  const WalletTransactionList({
    super.key,
    required this.transactions,
    required this.today,
  });

  final List<DriverWalletTransaction> transactions;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Chưa có giao dịch',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    final groups = _groupByVietnamDate(transactions);
    return Column(
      children: [
        for (var index = 0; index < groups.length; index++) ...[
          _TransactionDayGroup(group: groups[index], today: today),
          if (index != groups.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _TransactionDayGroup extends StatelessWidget {
  const _TransactionDayGroup({required this.group, required this.today});

  final _WalletTransactionDay group;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.bgLight,
            child: Row(
              children: [
                const Icon(
                  Icons.event_rounded,
                  size: 18,
                  color: AppColors.info,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _dayLabel(group.date, today),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${group.transactions.length} giao dịch',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < group.transactions.length; index++) ...[
            _TransactionRow(transaction: group.transactions[index]),
            if (index != group.transactions.length - 1)
              const Divider(height: 1, indent: 70, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final DriverWalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final pending = transaction.status == 'pending';
    final failed =
        transaction.status == 'failed' || transaction.status == 'expired';
    final positive = transaction.signedAmount >= 0;
    final color = pending
        ? AppColors.textSecondary
        : failed
        ? AppColors.error
        : positive
        ? AppColors.success
        : AppColors.error;
    final local = VietnamTime.toWallClock(transaction.createdAt);
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')} · '
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}';
    return Semantics(
      label: '${transaction.label}, $time',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.md,
              ),
              child: Icon(
                pending
                    ? Icons.schedule_rounded
                    : failed
                    ? Icons.close_rounded
                    : positive
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                color: color,
                size: 19,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    pending
                        ? 'Đang xử lý'
                        : failed
                        ? 'Thất bại'
                        : time,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${pending || failed
                  ? ''
                  : positive
                  ? '+'
                  : '-'}'
              '${formatVnd(transaction.signedAmount.abs())}',
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletTransactionDay {
  const _WalletTransactionDay({required this.date, required this.transactions});

  final DateTime date;
  final List<DriverWalletTransaction> transactions;
}

List<_WalletTransactionDay> _groupByVietnamDate(
  List<DriverWalletTransaction> transactions,
) {
  final groups = <DateTime, List<DriverWalletTransaction>>{};
  for (final transaction in transactions) {
    final wallClock = VietnamTime.toWallClock(transaction.createdAt);
    final date = DateTime(wallClock.year, wallClock.month, wallClock.day);
    groups.putIfAbsent(date, () => []).add(transaction);
  }
  final dates = groups.keys.toList()
    ..sort((left, right) => right.compareTo(left));
  return [
    for (final date in dates)
      _WalletTransactionDay(date: date, transactions: groups[date]!),
  ];
}

String _dayLabel(DateTime date, DateTime today) {
  String two(int value) => value.toString().padLeft(2, '0');
  final todayDate = DateTime(today.year, today.month, today.day);
  final difference = todayDate.difference(date).inDays;
  final prefix = switch (difference) {
    0 => 'Hôm nay',
    1 => 'Hôm qua',
    _ => switch (date.weekday) {
      DateTime.monday => 'Thứ Hai',
      DateTime.tuesday => 'Thứ Ba',
      DateTime.wednesday => 'Thứ Tư',
      DateTime.thursday => 'Thứ Năm',
      DateTime.friday => 'Thứ Sáu',
      DateTime.saturday => 'Thứ Bảy',
      _ => 'Chủ Nhật',
    },
  };
  return '$prefix · ${two(date.day)}/${two(date.month)}/${date.year}';
}
