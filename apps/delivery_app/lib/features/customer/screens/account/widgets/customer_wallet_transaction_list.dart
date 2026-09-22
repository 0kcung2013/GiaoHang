import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../../../core/models/customer_wallet.dart';

class CustomerWalletTransactionList extends StatelessWidget {
  const CustomerWalletTransactionList({
    super.key,
    required this.transactions,
    required this.today,
  });

  final List<CustomerWalletTransaction> transactions;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return const _EmptyHistory();
    final groups = _groupByVietnamDate(transactions);

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        AppSpacing.xl2,
      ),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) =>
          _TransactionDayGroup(group: groups[index], today: today),
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
            _TransactionTile(transaction: group.transactions[index]),
            if (index != group.transactions.length - 1)
              const Divider(height: 1, indent: 70, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final CustomerWalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.availableDelta >= 0;
    final color = positive ? AppColors.success : AppColors.error;
    final amount = transaction.availableDelta.abs();
    final local = VietnamTime.toWallClock(transaction.createdAt);
    final time = '${_two(local.hour)}:${_two(local.minute)}';

    return Semantics(
      label:
          '${transaction.label}, ${positive ? 'cộng' : 'trừ'} '
          '${formatVnd(amount)}, $time',
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
                positive ? Icons.south_west_rounded : Icons.north_east_rounded,
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
                    time,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${positive ? '+' : '-'}${formatVnd(amount)}',
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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.accent,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Không có giao dịch trong kỳ',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Chọn kỳ khác để xem các khoản COD đã quyết toán.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
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
  final List<CustomerWalletTransaction> transactions;
}

List<_WalletTransactionDay> _groupByVietnamDate(
  List<CustomerWalletTransaction> transactions,
) {
  final groups = <DateTime, List<CustomerWalletTransaction>>{};
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
  return '$prefix · ${_two(date.day)}/${_two(date.month)}/${date.year}';
}

String _two(int value) => value.toString().padLeft(2, '0');
