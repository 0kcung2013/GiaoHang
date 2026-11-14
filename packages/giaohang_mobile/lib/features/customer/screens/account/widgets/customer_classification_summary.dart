import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_reporting/giaohang_reporting.dart';
import '../../../../../core/models/user_model.dart';
import '../../../../help_center/screens/general_support_chat_screen.dart';
import '../../../../../core/mobile_app_role.dart';
import '../constants/customer_classification_strings.dart';
import 'account_components.dart';

class CustomerClassificationSummary extends StatelessWidget {
  const CustomerClassificationSummary({super.key, required this.profile});
  final UserModel profile;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.screenH),
    children: [
      Icon(
        profile.customerType == 'business'
            ? Icons.storefront_rounded
            : Icons.person_rounded,
        size: 40,
        color: AppColors.accent,
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        profile.customerType == 'business'
            ? CustomerClassificationStrings.businessProfile
            : CustomerClassificationStrings.individual,
        style: AppTextStyles.headingLarge,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        CustomerClassificationStrings.locked,
        style: AppTextStyles.bodyMedium,
      ),
      if (profile.customerType == 'business') ...[
        const SizedBox(height: AppSpacing.xl),
        CustomerAccountSurface(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CustomerClassificationStrings.declared,
                  style: AppTextStyles.labelMedium,
                ),
                for (final field in [
                  (
                    CustomerClassificationStrings.businessName,
                    profile.businessName,
                  ),
                  (
                    CustomerClassificationStrings.businessAddress,
                    profile.businessAddress,
                  ),
                  (
                    CustomerClassificationStrings.taxCode,
                    profile.businessTaxCode,
                  ),
                ]) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(field.$1, style: AppTextStyles.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    field.$2?.isNotEmpty == true
                        ? field.$2!
                        : CustomerClassificationStrings.missing,
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.textOnAccent,
            minimumSize: const Size.fromHeight(52),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => BusinessReportScreen(customerId: profile.id),
            ),
          ),
          icon: const Icon(Icons.summarize_rounded),
          label: const Text(BusinessReportStrings.title),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                const GeneralSupportChatScreen(role: MobileAppRole.customer),
          ),
        ),
        icon: const Icon(Icons.support_agent_rounded),
        label: const Text(CustomerClassificationStrings.correction),
      ),
    ],
  );
}
