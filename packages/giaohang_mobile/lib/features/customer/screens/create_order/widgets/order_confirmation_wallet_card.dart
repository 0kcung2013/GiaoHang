import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../utils/order_payment_strings.dart';
import 'confirmation_components.dart';
import 'customer_order_wallet_panel.dart';

class OrderConfirmationWalletCard extends StatelessWidget {
  const OrderConfirmationWalletCard({
    super.key,
    required this.deliveryFee,
    required this.useVnpay,
    required this.canSwitch,
    required this.onVnpaySelected,
    this.error,
  });

  final int deliveryFee;
  final bool useVnpay;
  final bool canSwitch;
  final VoidCallback onVnpaySelected;
  final String? error;

  @override
  Widget build(BuildContext context) => ConfirmationCard(
    children: [
      ConfirmationCardTitle(
        icon: useVnpay
            ? Icons.account_balance_rounded
            : Icons.account_balance_wallet_rounded,
        title: useVnpay
            ? OrderPaymentText.vnpaySelected
            : OrderPaymentText.prepaidPayer,
        accentColor: AppColors.accent,
      ),
      if (!useVnpay) ...[
        const SizedBox(height: AppSpacing.md),
        CustomerOrderWalletPanel(deliveryFee: deliveryFee),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
        if (canSwitch) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onVnpaySelected,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(48, 48),
            ),
            child: const Text(OrderPaymentText.vnpayAlternative),
          ),
        ],
      ],
    ],
  );
}
