import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../support_orders/models/support_order.dart';
import '../../support_orders/utils/support_order_ui.dart';
import '../constants/admin_strings.dart';
import 'admin_surface.dart';

class AdminOrderTable extends StatelessWidget {
  const AdminOrderTable({
    super.key,
    required this.orders,
    required this.onOpen,
  });
  final List<SupportOrder> orders;
  final ValueChanged<SupportOrder> onOpen;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 900 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.3;
      return AdminSurface(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            if (wide)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    _cell(AdminStrings.orderCode, 2),
                    _cell(AdminStrings.route, 4),
                    _cell(AdminStrings.status, 2),
                    _cell(AdminStrings.amount, 2),
                    _cell(AdminStrings.created, 2),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            for (final order in orders) ...[
              const Divider(height: 1),
              Semantics(
                button: true,
                label: '${AdminStrings.details} ${order.trackingCode}',
                child: InkWell(
                  key: ValueKey('admin-order-${order.id}'),
                  onTap: () => onOpen(order),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: wide
                        ? Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  order.trackingCode,
                                  style: AppTextStyles.mono,
                                ),
                              ),
                              Expanded(flex: 4, child: _addresses(order)),
                              Expanded(flex: 2, child: _status(order)),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  formatVnd(order.totalPrice),
                                  style: AppTextStyles.labelMedium,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  SupportOrderUi.formatDateTime(
                                    order.createdAt,
                                  ),
                                  style: AppTextStyles.bodySmall,
                                ),
                              ),
                              const SizedBox(
                                width: 48,
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: AppSpacing.md,
                                runSpacing: AppSpacing.sm,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    order.trackingCode,
                                    style: AppTextStyles.mono,
                                  ),
                                  _status(order),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _addresses(order),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.xl,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  Text(
                                    formatVnd(order.totalPrice),
                                    style: AppTextStyles.labelLarge,
                                  ),
                                  Text(
                                    SupportOrderUi.formatDateTime(
                                      order.createdAt,
                                    ),
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
  Widget _cell(String label, int flex) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
    ),
  );
  Widget _addresses(SupportOrder order) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        order.pickupAddress,
        style: AppTextStyles.bodySmall,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        '→ ${order.deliveryAddress}',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
  Widget _status(SupportOrder order) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: SupportOrderUi.statusColor(order.status).withValues(alpha: .1),
        borderRadius: AppRadius.sm,
      ),
      child: Text(
        SupportOrderUi.statusLabel(order.status),
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textPrimary),
      ),
    ),
  );
}
