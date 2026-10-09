import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/utils/vnd_input_formatter.dart';
import '../controllers/order_finance_form_controller.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../utils/order_payment_strings.dart';
import 'order_payment_choices.dart';
import 'order_field_label.dart';

class CreateOrderPaymentBody extends StatelessWidget {
  const CreateOrderPaymentBody({
    super.key,
    required this.formKey,
    required this.controller,
    required this.deliveryFee,
  });
  final GlobalKey<FormState> formKey;
  final OrderFinanceFormController controller;
  final double deliveryFee;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: [
                _Surface(
                  children: [
                    Text(
                      OrderPaymentText.goods,
                      style: AppTextStyles.headingSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OrderPaymentChoices(
                      collectCod: controller.collectCod,
                      onChanged: controller.setCollectCod,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: ValueKey(controller.collectCod),
                      controller: controller.collectCod
                          ? controller.codCollectionController
                          : controller.goodsValueController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: const [VndInputFormatter()],
                      style: AppTextStyles.headingSmall,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        final amount = parseVndInput(value ?? '');
                        if (amount <= 0) {
                          return controller.collectCod
                              ? OrderPaymentText.required
                              : OrderPaymentText.goodsValueRequired;
                        }
                        return amount > 2000000 ? OrderPaymentText.limit : null;
                      },
                      decoration: InputDecoration(
                        label: OrderFieldLabel(
                          controller.collectCod
                              ? OrderPaymentText.amount
                              : OrderPaymentText.goodsValue,
                        ),
                        hintText: '0',
                        suffixText: 'đ',
                        filled: true,
                        fillColor: AppColors.bgLight,
                        border: const OutlineInputBorder(
                          borderRadius: AppRadius.md,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: AppRadius.md,
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: AppRadius.md,
                          borderSide: BorderSide(color: AppColors.accent),
                        ),
                      ),
                    ),
                    if (!controller.collectCod) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        OrderPaymentText.depositHint,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _Surface(
                  children: [
                    _Amount(label: OrderPaymentText.fee, amount: deliveryFee),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      controller.collectCod
                          ? OrderPaymentText.payer
                          : OrderPaymentText.prepaidPayer,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  liveRegion: true,
                  child: _Surface(
                    emphasized: true,
                    children: [
                      _Amount(
                        label: OrderPaymentText.total,
                        amount: controller
                            .financeFor(deliveryFee.round())
                            .receiverCollectionAmount
                            .toDouble(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.children, this.emphasized = false});
  final List<Widget> children;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: emphasized ? AppColors.accentLight : AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: Border.all(
        color: emphasized ? AppColors.accent : AppColors.border,
      ),
      boxShadow: AppShadow.subtle,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.amount});
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.sm,
    children: [
      Text(label, style: AppTextStyles.labelMedium),
      Text(
        formatVnd(amount.round()),
        style: AppTextStyles.headingSmall.copyWith(color: AppColors.accent),
      ),
    ],
  );
}
