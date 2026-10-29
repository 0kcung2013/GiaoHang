import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show formatVnd;

import '../models/customer_payment.dart';
import '../payment_strings.dart';
import '../utils/payment_format.dart';

Future<void> showPaymentExplanation(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PaymentStrings.explanation,
                style: AppTextStyles.headingMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(PaymentStrings.calculation, style: AppTextStyles.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(PaymentStrings.close),
              ),
            ],
          ),
        ),
      ),
    );

Future<void> showCustomerPaymentDetail(
  BuildContext context,
  CustomerPayment payment,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: AppColors.bgCard,
  constraints: const BoxConstraints(maxWidth: 640),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(formatVnd(payment.amount), style: AppTextStyles.displayMedium),
          const SizedBox(height: AppSpacing.xl),
          for (final field in [
            (PaymentStrings.method, payment.method.label),
            (PaymentStrings.status, payment.state.label),
            (PaymentStrings.reference, payment.reference),
            if (payment.trackingCode != null)
              (PaymentStrings.order, payment.trackingCode!),
            (PaymentStrings.createdAt, customerPaymentDate(payment.createdAt)),
          ]) ...[
            Text(
              field.$1,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SelectableText(field.$2, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(PaymentStrings.close),
          ),
        ],
      ),
    ),
  ),
);
