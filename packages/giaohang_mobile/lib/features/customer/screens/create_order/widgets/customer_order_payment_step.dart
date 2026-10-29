import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../../../core/utils/platform_fee_strings.dart';
import '../../account/providers/customer_account_providers.dart';
import '../controllers/order_finance_form_controller.dart';
import 'create_order_payment_body.dart';

/// Chốt cùng cấu hình đã dùng để báo cước; không đoán phí khi hồ sơ chưa tải.
class CustomerOrderPaymentStep extends ConsumerWidget {
  const CustomerOrderPaymentStep({
    super.key,
    required this.formKey,
    required this.controller,
    required this.deliveryFee,
    this.settings,
  });
  final GlobalKey<FormState> formKey;
  final OrderFinanceFormController controller;
  final double deliveryFee;
  final BusinessSettings? settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(customerAccountProfileProvider)
      .when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(PlatformFeeText.profileError),
              TextButton(
                onPressed: () => ref.invalidate(customerAccountProfileProvider),
                child: const Text(PlatformFeeText.retry),
              ),
            ],
          ),
        ),
        data: (profile) => profile == null
            ? const Center(child: Text(PlatformFeeText.profileError))
            : CreateOrderPaymentBody(
                formKey: formKey,
                controller: controller,
                deliveryFee: deliveryFee,
                settings: settings,
                customerPlatformFeeAmount:
                    BusinessSettings.calculatePlatformFee(
                      deliveryFee.round(),
                      settings?.customerPlatformFeeBps(
                            profile.customerType ?? 'individual',
                          ) ??
                          0,
                    ),
              ),
      );
}
