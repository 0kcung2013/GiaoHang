import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../../../../../core/utils/vnd_input_formatter.dart';

Future<int?> showCustomerWalletWithdrawSheet(
  BuildContext context, {
  required int availableBalance,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.primary.withValues(alpha: 0.42),
    builder: (_) =>
        _CustomerWalletWithdrawSheet(availableBalance: availableBalance),
  );
}

class _CustomerWalletWithdrawSheet extends StatefulWidget {
  const _CustomerWalletWithdrawSheet({required this.availableBalance});

  final int availableBalance;

  @override
  State<_CustomerWalletWithdrawSheet> createState() =>
      _CustomerWalletWithdrawSheetState();
}

class _CustomerWalletWithdrawSheetState
    extends State<_CustomerWalletWithdrawSheet> {
  late final TextEditingController _controller;

  int get _amount => parseVndInput(_controller.text);
  bool get _canSubmit => _amount > 0 && _amount <= widget.availableBalance;

  @override
  void initState() {
    super.initState();
    final suggested = widget.availableBalance.clamp(0, 500000);
    _controller = TextEditingController(
      text: suggested == 0 ? '' : formatVndDigits(suggested),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        <int>{100000, 200000, 500000, widget.availableBalance}
            .where((value) => value > 0 && value <= widget.availableBalance)
            .toList()
          ..sort();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            AppSpacing.xl2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: AppSpacing.sm),
              _SheetHeader(onClose: () => Navigator.of(context).pop()),
              const SizedBox(height: AppSpacing.xl),
              const _DemoBankAccount(),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Số tiền muốn rút',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'Khả dụng ${formatVnd(widget.availableBalance)}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('customer_wallet_withdraw_amount'),
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: const [VndInputFormatter()],
                onChanged: (_) => setState(() {}),
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bgLight,
                  hintText: '0',
                  hintStyle: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                  suffixText: 'đ',
                  suffixStyle: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.lg,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.md,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.md,
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  errorText: _amount > widget.availableBalance
                      ? 'Số tiền vượt quá số dư khả dụng'
                      : null,
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final value in suggestions)
                      ActionChip(
                        label: Text(
                          value == widget.availableBalance
                              ? 'Tất cả'
                              : _compactMoney(value),
                        ),
                        onPressed: () => setState(
                          () => _controller.text = formatVndDigits(value),
                        ),
                        labelStyle: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                        ),
                        backgroundColor: AppColors.bgCard,
                        side: const BorderSide(color: AppColors.border),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.full,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              const _DemoNotice(),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  key: const ValueKey('customer_wallet_withdraw_confirm'),
                  onPressed: _canSubmit
                      ? () => Navigator.of(context).pop(_amount)
                      : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Xác nhận rút tiền'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.border,
                    foregroundColor: AppColors.textOnAccent,
                    disabledForegroundColor: AppColors.textMuted,
                    textStyle: AppTextStyles.labelLarge,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ExcludeSemantics(
        child: Container(
          width: 40,
          height: 4,
          decoration: const BoxDecoration(
            color: AppColors.border,
            borderRadius: AppRadius.full,
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rút tiền',
                style: AppTextStyles.headingLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Bản trình diễn · không tạo giao dịch thật',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: 'Đóng',
          style: IconButton.styleFrom(
            minimumSize: const Size.square(48),
            foregroundColor: AppColors.textSecondary,
            backgroundColor: AppColors.bgLight,
          ),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _DemoBankAccount extends StatelessWidget {
  const _DemoBankAccount();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgWarm,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: AppRadius.md,
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: AppColors.accent,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tài khoản nhận (demo)',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Ngân hàng liên kết  •••• 6868',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            color: AppColors.success,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.info,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Xác nhận chỉ hiển thị phản hồi mô phỏng và không làm thay đổi '
              'số dư Ví.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _compactMoney(int value) {
  if (value >= 1000000 && value % 1000000 == 0) {
    return '${value ~/ 1000000} triệu';
  }
  if (value >= 1000 && value % 1000 == 0) {
    return '${value ~/ 1000}K';
  }
  return formatVnd(value);
}
