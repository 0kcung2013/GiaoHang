import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import 'constants/customer_account_strings.dart';
import 'constants/customer_classification_strings.dart';
import 'providers/customer_account_providers.dart';
import 'widgets/account_components.dart';
import 'widgets/customer_classification_form.dart';

class CustomerClassificationScreen extends ConsumerWidget {
  const CustomerClassificationScreen({super.key, this.onboarding = false});
  final bool onboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: AppColors.bgLight,
    appBar: AppBar(
      automaticallyImplyLeading: !onboarding,
      backgroundColor: AppColors.bgCard,
      title: Text(
        CustomerClassificationStrings.accountTitle,
        style: AppTextStyles.headingMedium,
      ),
      actions: [
        if (onboarding)
          TextButton(
            onPressed: () => context.push('/help'),
            child: const Text(CustomerClassificationStrings.support),
          ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ref
              .watch(customerAccountProfileProvider)
              .when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (_, _) => CustomerAccountState(
                  message: CustomerAccountStrings.loadError,
                  onRetry: () => ref.invalidate(customerAccountProfileProvider),
                ),
                data: (profile) => profile == null
                    ? const CustomerAccountState(
                        message: CustomerAccountStrings.signIn,
                      )
                    : CustomerClassificationForm(
                        key: ValueKey(profile.id),
                        profile: profile,
                        onboarding: onboarding,
                      ),
              ),
        ),
      ),
    ),
  );
}
