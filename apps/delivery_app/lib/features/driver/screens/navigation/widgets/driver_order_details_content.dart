import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/order_cargo_utils.dart';
import '../../../finance/models/driver_goods_deposit.dart';
import 'driver_order_cargo_details.dart';
import '../../home/widgets/driver_order_finance_panel.dart';
import '../../home/widgets/driver_order_offer_summary.dart';

class DriverOrderDetailsContent extends StatelessWidget {
  const DriverOrderDetailsContent({
    super.key,
    required this.order,
    this.status,
    this.notice,
    this.cancellationAction,
    this.goodsDeposit,
  });

  final OrderModel order;
  final Widget? status;
  final Widget? notice;
  final Widget? cancellationAction;
  final DriverGoodsDeposit? goodsDeposit;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('driver-order-details-scroll'),
    padding: const EdgeInsets.all(AppSpacing.screenH),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (status != null) ...[
              Align(alignment: Alignment.centerLeft, child: status),
              const SizedBox(height: AppSpacing.md),
            ],
            if (notice != null) ...[
              notice!,
              const SizedBox(height: AppSpacing.md),
            ],
            _Section(
              child: DriverOrderRouteSummary(order: order, showDistance: false),
            ),
            const SizedBox(height: AppSpacing.md),
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DriverOrderPresentationStrings.cargo,
                    style: AppTextStyles.headingSmall,
                  ),
                  const Divider(
                    height: AppSpacing.xl2,
                    color: AppColors.border,
                  ),
                  if (!hasCargoInfo(order))
                    Text(
                      DriverOrderPresentationStrings.emptyCargo,
                      style: AppTextStyles.bodyMedium,
                    )
                  else
                    DriverOrderCargoDetails(order: order),
                  if (order.note?.trim().isNotEmpty == true) ...[
                    const Divider(
                      height: AppSpacing.xl2,
                      color: AppColors.border,
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_rounded,
                          size: 20,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            DriverOrderPresentationStrings.note,
                            style: AppTextStyles.labelLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(order.note!.trim(), style: AppTextStyles.bodyMedium),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DriverOrderFinancePanel(order: order, goodsDeposit: goodsDeposit),
            if (cancellationAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              cancellationAction!,
            ],
          ],
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: const BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.md,
    ),
    child: child,
  );
}
