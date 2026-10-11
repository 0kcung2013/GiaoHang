import 'package:flutter/material.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../utils/support_order_information_strings.dart';
import '../utils/support_order_ui.dart';
import 'support_order_information_components.dart';

class SupportOrderPaymentCard extends StatelessWidget {
  const SupportOrderPaymentCard({required this.order, super.key});
  final RiskOrderSummary order;

  String? _money(int? value) => value == null ? null : formatVnd(value);

  @override
  Widget build(BuildContext context) => SupportOrderInfoSection(
    title: SupportOrderInformationStrings.payment,
    icon: Icons.receipt_long_rounded,
    child: SupportOrderInfoFacts(
      children: [
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.goodsValue,
          value: _money(order.goodsValue),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.cod,
          value: _money(order.codCollectionAmount),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.fee,
          value: formatVnd(order.deliveryFee),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.total,
          value: _money(order.totalPrice),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.payer,
          value: SupportOrderUi.feePayerLabel(order.deliveryFeePayer),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.method,
          value: SupportOrderUi.paymentLabel(order.paymentMethod),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.paymentStatus,
          value: SupportOrderUi.paymentStatusLabel(order.paymentStatus),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.receiverCollection,
          value: _money(order.receiverCollectionAmount),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.driverAdvance,
          value: _money(order.driverAdvanceAmount),
        ),
        SupportOrderInfoFact(
          label: SupportOrderInformationStrings.earning,
          value: _money(order.driverNetEarning),
        ),
      ],
    ),
  );
}
