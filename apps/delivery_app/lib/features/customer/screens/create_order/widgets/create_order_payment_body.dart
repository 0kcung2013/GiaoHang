import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_finance.dart';
import '../../../../../core/utils/delivery_fee_calculator.dart';
import '../utils/create_order_formatters.dart';
import 'order_payment_method_section.dart';

class CreateOrderPaymentBody extends StatelessWidget {
  const CreateOrderPaymentBody({
    super.key,
    required this.quote,
    required this.deliveryFeePayer,
    required this.onDeliveryFeePayerChanged,
  });

  final DeliveryFeeEstimate quote;
  final DeliveryFeePayer deliveryFeePayer;
  final ValueChanged<DeliveryFeePayer> onDeliveryFeePayerChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.xl2,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.lg,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_shipping_rounded,
                    color: AppColors.accent,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Phí giao hàng',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    formatDeliveryFee(quote.deliveryFee),
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OrderPaymentMethodSection(
              deliveryFeePayer: deliveryFeePayer,
              onDeliveryFeePayerChanged: onDeliveryFeePayerChanged,
            ),
          ],
        ),
      ),
    );
  }
}
