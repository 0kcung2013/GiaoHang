import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../utils/support_order_information_strings.dart';
import '../utils/support_order_ui.dart';
import 'support_order_cargo_card.dart';
import 'support_order_information_components.dart';
import 'support_order_payment_card.dart';
import 'support_order_route_contacts.dart';
import 'support_order_monitoring_card.dart';

/// Nội dung đối chiếu chung của tra cứu đơn, hội thoại và hồ sơ sự cố CSKH.
class SupportOrderInformation extends StatelessWidget {
  const SupportOrderInformation({
    required this.order,
    this.onContactCustomer,
    this.onContactDriver,
    this.showIdentity = true,
    super.key,
  });
  final RiskOrderSummary order;
  final VoidCallback? onContactCustomer;
  final VoidCallback? onContactDriver;
  final bool showIdentity;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showIdentity) ...[
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            SelectableText(order.trackingCode, style: AppTextStyles.mono),
            Text(
              SupportOrderUi.statusLabel(order.status),
              style: AppTextStyles.labelMedium.copyWith(
                color: SupportOrderUi.statusColor(order.status),
              ),
            ),
            Text(
              order.hasPickedUp
                  ? SupportOrderInformationStrings.pickedUp
                  : SupportOrderInformationStrings.notPickedUp,
              style: AppTextStyles.labelMedium,
            ),
          ],
        ),
        if (order.statusNote?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            order.statusNote!,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
      LayoutBuilder(
        builder: (context, constraints) {
          final cargoAndRoute = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SupportOrderCargoCard(order: order),
              const SizedBox(height: AppSpacing.lg),
              SupportOrderRouteContacts(
                order: order,
                onContactCustomer: onContactCustomer,
                onContactDriver: onContactDriver,
              ),
            ],
          );
          final financeAndTime = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SupportOrderPaymentCard(order: order),
              const SizedBox(height: AppSpacing.lg),
              _Timing(order: order),
              if (order.driverMonitoring != null) ...[
                const SizedBox(height: AppSpacing.lg),
                SupportOrderMonitoringCard(order: order),
              ],
            ],
          );
          if (constraints.maxWidth >= 900 &&
              MediaQuery.textScalerOf(context).scale(1) < 1.4) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: cargoAndRoute),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 5, child: financeAndTime),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cargoAndRoute,
              const SizedBox(height: AppSpacing.lg),
              financeAndTime,
            ],
          );
        },
      ),
    ],
  );
}

class _Timing extends StatelessWidget {
  const _Timing({required this.order});
  final RiskOrderSummary order;

  String? _time(DateTime? value) =>
      value == null ? null : SupportOrderUi.formatDateTime(value);

  @override
  Widget build(BuildContext context) => SupportOrderInfoSection(
    title: SupportOrderInformationStrings.timing,
    icon: Icons.schedule_rounded,
    child: SupportOrderInfoFacts(
      children: [
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.service,
          value: SupportOrderUi.serviceLabel(order.serviceType),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.created,
          value: _time(order.createdAt),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.updated,
          value: _time(order.updatedAt),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.predicted,
          value:
              _time(order.predictedDeliveryAt) ??
              (order.driverId == null
                  ? SupportOrderInformationStrings.awaitingDriver
                  : null),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.deadline,
          value: _time(order.estimatedDeliveryAt),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.actualPickup,
          value:
              _time(order.actualPickedUpAt) ??
              (order.hasPickedUp
                  ? SupportOrderInformationStrings.pickupTimeMissing
                  : SupportOrderInformationStrings.notPickedUp),
        ),
        if (order.actualDeliveredAt != null)
          SupportOrderInfoFact(
            label: SupportOrderInformationStrings.actualDelivery,
            value: _time(order.actualDeliveredAt),
          ),
        if (order.cancelledAt != null)
          SupportOrderInfoFact(
            label: SupportOrderInformationStrings.cancelled,
            value: _time(order.cancelledAt),
          ),
      ],
    ),
  );
}
