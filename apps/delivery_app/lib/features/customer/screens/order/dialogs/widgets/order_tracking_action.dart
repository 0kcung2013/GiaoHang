import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../order_detail_strings.dart';

const orderTrackingActionKey = Key('order-tracking-action');

class OrderTrackingAction extends StatelessWidget {
  const OrderTrackingAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        key: orderTrackingActionKey,
        onPressed: onPressed,
        icon: const Icon(Icons.near_me_rounded),
        label: const Text(OrderDetailStrings.trackAction),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textOnAccent,
          textStyle: AppTextStyles.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
        ),
      ),
    );
  }
}
