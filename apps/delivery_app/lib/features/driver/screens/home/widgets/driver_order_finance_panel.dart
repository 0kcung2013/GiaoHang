import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/money_formatter.dart';

abstract final class DriverFinanceText {
  static const pickup = 'Lấy';
  static const delivery = 'Giao';
  static const pay = 'Trả';
  static const collect = 'Thu';
  static const wallet = 'Ứng qua ví · không trả tiền mặt';
  static const noAdvance = 'Không cần ứng tiền';
  static const recipient = 'Thu từ người nhận';
  static const noCollection = 'Không thu tiền người nhận';
  static String earning(int amount) => 'Thực nhận ${formatVnd(amount)}';
  static String topUp(int amount) => 'Nạp thêm ${formatVnd(amount)}';
}

class DriverOrderFinancePanel extends StatefulWidget {
  const DriverOrderFinancePanel({
    super.key,
    required this.order,
    this.availableBalance,
  });
  final OrderModel order;
  final int? availableBalance;

  @override
  State<DriverOrderFinancePanel> createState() =>
      _DriverOrderFinancePanelState();
}

class _DriverOrderFinancePanelState extends State<DriverOrderFinancePanel> {
  late bool _delivery =
      widget.order.status == 'delivering' || widget.order.status == 'delivered';

  @override
  void didUpdateWidget(covariant DriverOrderFinancePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.status != widget.order.status) {
      _delivery =
          widget.order.status == 'delivering' ||
          widget.order.status == 'delivered';
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final amount = _delivery
        ? order.receiverCollectionAmount
        : order.driverAdvanceAmount;
    final missing = widget.availableBalance == null
        ? 0
        : (order.driverAdvanceAmount - widget.availableBalance!).clamp(
            0,
            order.driverAdvanceAmount,
          );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Tab(
                  label: DriverFinanceText.pickup,
                  selected: !_delivery,
                  onTap: () => setState(() => _delivery = false),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Tab(
                  label: DriverFinanceText.delivery,
                  selected: _delivery,
                  onTap: () => setState(() => _delivery = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                _delivery ? DriverFinanceText.collect : DriverFinanceText.pay,
                style: AppTextStyles.labelLarge,
              ),
              Text(
                formatVnd(amount),
                style: AppTextStyles.headingLarge.copyWith(
                  color: amount == 0 ? AppColors.success : AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _delivery
                ? (amount == 0
                      ? DriverFinanceText.noCollection
                      : DriverFinanceText.recipient)
                : (amount == 0
                      ? DriverFinanceText.noAdvance
                      : DriverFinanceText.wallet),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Divider(height: AppSpacing.xl, color: AppColors.border),
          Text(
            DriverFinanceText.earning(order.driverNetEarning),
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.success),
          ),
          if (missing > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              DriverFinanceText.topUp(missing),
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.accentLight : AppColors.bgLight,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: selected ? AppColors.accent : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
