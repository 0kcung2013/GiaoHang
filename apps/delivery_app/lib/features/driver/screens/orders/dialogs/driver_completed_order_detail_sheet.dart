import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../../../../../core/utils/order_cargo_utils.dart';
import '../../../../../core/widgets/order_cargo_info_block.dart';
import '../../home/utils/driver_home_formatters.dart';
import '../utils/driver_orders_strings.dart';

Future<void> showDriverCompletedOrderDetailSheet({
  required BuildContext context,
  required OrderModel order,
  Future<void> Function()? onRateCustomer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.58,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, scrollController) => _DriverCompletedOrderDetailSheet(
        order: order,
        scrollController: scrollController,
        onRateCustomer: onRateCustomer == null
            ? null
            : () async {
                Navigator.of(sheetContext).pop();
                await onRateCustomer();
              },
      ),
    ),
  );
}

class _DriverCompletedOrderDetailSheet extends StatelessWidget {
  const _DriverCompletedOrderDetailSheet({
    required this.order,
    required this.scrollController,
    this.onRateCustomer,
  });

  final OrderModel order;
  final ScrollController scrollController;
  final Future<void> Function()? onRateCustomer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgLight,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          AppSpacing.xl3,
        ),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: AppRadius.full,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _DetailHeader(order: order),
          const SizedBox(height: AppSpacing.lg),
          _DetailSection(
            title: DriverOrdersStrings.routeTitle,
            icon: Icons.route_rounded,
            child: _RouteDetails(order: order),
          ),
          if (_hasRecipient(order)) ...[
            const SizedBox(height: AppSpacing.md),
            _DetailSection(
              title: DriverOrdersStrings.recipientTitle,
              icon: Icons.person_rounded,
              child: Column(
                children: [
                  _ValueRow(
                    label: 'Họ tên',
                    value: order.recipientName?.trim().isNotEmpty == true
                        ? order.recipientName!.trim()
                        : 'Khách hàng',
                  ),
                  if ((order.recipientPhone ?? '').trim().isNotEmpty)
                    _ValueRow(
                      label: 'Số điện thoại',
                      value: order.recipientPhone!.trim(),
                    ),
                ],
              ),
            ),
          ],
          if (hasCargoInfo(order)) ...[
            const SizedBox(height: AppSpacing.md),
            _DetailSection(
              title: DriverOrdersStrings.cargoTitle,
              icon: Icons.inventory_2_rounded,
              child: OrderCargoInfoBlock(order: order),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _DetailSection(
            title: DriverOrdersStrings.financeTitle,
            icon: Icons.receipt_long_rounded,
            child: Column(
              children: [
                _ValueRow(
                  label: DriverOrdersStrings.goodsValueLabel,
                  value: formatVnd(order.goodsValue),
                ),
                _ValueRow(
                  label: DriverOrdersStrings.codLabel,
                  value: formatVnd(order.codCollectionAmount),
                ),
                _ValueRow(
                  label: DriverOrdersStrings.deliveryFeeLabel,
                  value: formatVnd(order.deliveryFee),
                ),
                _ValueRow(
                  label: DriverOrdersStrings.receiverCollectionLabel,
                  value: formatVnd(order.receiverCollectionAmount),
                ),
                _ValueRow(
                  label: DriverOrdersStrings.paymentMethodLabel,
                  value: _paymentLabel(order.paymentMethod),
                ),
                const Divider(height: AppSpacing.xl, color: AppColors.border),
                _ValueRow(
                  label: DriverOrdersStrings.driverIncomeLabel,
                  value: formatVnd(
                    order.driverNetEarning > 0
                        ? order.driverNetEarning
                        : order.deliveryFee,
                  ),
                  emphasized: true,
                ),
              ],
            ),
          ),
          if ((order.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DetailSection(
              title: DriverOrdersStrings.noteTitle,
              icon: Icons.sticky_note_2_rounded,
              child: Text(
                order.note!.trim(),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
          if (onRateCustomer != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRateCustomer,
              icon: const Icon(Icons.star_rounded),
              label: const Text(DriverOrdersStrings.rateCustomerLabel),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                textStyle: AppTextStyles.labelLarge,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.full,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasRecipient(OrderModel value) {
    return (value.recipientName ?? '').trim().isNotEmpty ||
        (value.recipientPhone ?? '').trim().isNotEmpty;
  }

  String _paymentLabel(String value) {
    return switch (value.toLowerCase()) {
      'cash' => 'Tiền mặt',
      'vnpay' => 'VNPay',
      _ => value,
    };
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: AppRadius.lg,
          ),
          child: const Icon(
            Icons.local_shipping_rounded,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DriverOrdersStrings.detailTitle,
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                displayOrderCode(order),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mono.copyWith(color: AppColors.accent),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${DriverOrdersStrings.completedLabel} lúc '
                '${deliveredTimeText(order)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Đóng',
          icon: const Icon(Icons.close_rounded),
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}

class _RouteDetails extends StatelessWidget {
  const _RouteDetails({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RouteStop(
          color: AppColors.markerPickup,
          icon: Icons.storefront_rounded,
          label: DriverOrdersStrings.pickupLabel,
          address: order.pickupAddress,
        ),
        const Padding(
          padding: EdgeInsets.only(left: 19),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 24,
              child: VerticalDivider(
                width: 1,
                thickness: 2,
                color: AppColors.border,
              ),
            ),
          ),
        ),
        _RouteStop(
          color: AppColors.markerDrop,
          icon: Icons.location_on_rounded,
          label: DriverOrdersStrings.deliveryLabel,
          address: order.deliveryAddress,
        ),
      ],
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.color,
    required this.icon,
    required this.label,
    required this.address,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.labelMedium.copyWith(
                color: emphasized ? AppColors.success : AppColors.textPrimary,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
