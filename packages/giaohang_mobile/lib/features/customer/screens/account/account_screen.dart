import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/widgets/platform_fee_card.dart';
import 'customer_classification_screen.dart';
import 'constants/customer_classification_strings.dart';
import '../../../../core/services/auth_service.dart';
import '../../../reviews/history/customer_review_history_screen.dart';
import '../../../reviews/history/review_history_strings.dart';
import '../create_order/utils/vietnam_phone_input.dart';
import '../payments/customer_payment_statistics_screen.dart';
import '../payments/payment_strings.dart';
import 'constants/customer_account_strings.dart';
import 'customer_addresses_screen.dart';
import 'customer_profile_screen.dart';
import 'customer_requests_screen.dart';
import 'customer_settings_screen.dart';
import 'providers/customer_account_providers.dart';
import 'widgets/account_components.dart';
import 'widgets/customer_wallet_card.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _signingOut = false;

  Future<void> _open(Widget page) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(CustomerAccountStrings.saved)),
      );
    }
  }

  Future<void> _signOut() async {
    if (_signingOut ||
        !await confirmCustomerAccountAction(
          context,
          title: CustomerAccountStrings.signOutTitle,
          confirm: CustomerAccountStrings.signOut,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _signingOut = true);
    try {
      await AuthService().signOut();
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        setState(() => _signingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(CustomerAccountStrings.signOutError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(customerAccountUserIdProvider);
    final profile = ref.watch(customerAccountProfileProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: RefreshIndicator(
          onRefresh: () async {
            if (userId != null) {
              refreshCustomerAccount(ref, userId);
              try {
                await ref.read(customerAccountProfileProvider.future);
              } catch (_) {
                // The profile provider renders the retry state after a failed refresh.
              }
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              Text(
                CustomerAccountStrings.title,
                style: AppTextStyles.headingLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              profile.when(
                loading: () =>
                    const LinearProgressIndicator(color: AppColors.accent),
                error: (_, _) => CustomerAccountState(
                  message: CustomerAccountStrings.loadError,
                  onRetry: () {
                    if (userId != null) refreshCustomerAccount(ref, userId);
                  },
                ),
                data: (value) => value == null
                    ? const CustomerAccountState(
                        message: CustomerAccountStrings.signIn,
                      )
                    : _profile(value),
              ),
              if (userId != null) ...[
                const SizedBox(height: AppSpacing.xl),
                const CustomerWalletCard(),
                const SizedBox(height: AppSpacing.lg),
                PlatformFeeCard(
                  customerType: profile.valueOrNull?.customerType,
                ),
                _group(CustomerAccountStrings.yourInformation, [
                  CustomerAccountAction(
                    icon: Icons.badge_outlined,
                    label: CustomerClassificationStrings.accountTitle,
                    onTap: () => _open(const CustomerClassificationScreen()),
                  ),
                  CustomerAccountAction(
                    icon: Icons.person_outline_rounded,
                    label: CustomerAccountStrings.profile,
                    onTap: profile.valueOrNull == null
                        ? null
                        : () => _open(
                            CustomerProfileScreen(
                              profile: profile.requireValue!,
                            ),
                          ),
                  ),
                  CustomerAccountAction(
                    icon: Icons.location_on_outlined,
                    label: CustomerAccountStrings.addresses,
                    onTap: () => _open(const CustomerAddressesScreen()),
                  ),
                ]),
                _group(CustomerAccountStrings.activity, [
                  CustomerAccountAction(
                    icon: Icons.bar_chart_rounded,
                    label: PaymentStrings.title,
                    onTap: () => _open(const CustomerPaymentStatisticsScreen()),
                  ),
                  CustomerAccountAction(
                    icon: Icons.history_rounded,
                    label: CustomerAccountStrings.history,
                    onTap: () =>
                        context.go('/customer-home?tab=orders&view=history'),
                  ),
                  CustomerAccountAction(
                    icon: Icons.star_outline_rounded,
                    label: ReviewHistoryStrings.title,
                    onTap: () => _open(const CustomerReviewHistoryScreen()),
                  ),
                  CustomerAccountAction(
                    icon: Icons.forum_outlined,
                    label: CustomerAccountStrings.requests,
                    onTap: () => _open(const CustomerRequestsScreen()),
                  ),
                ]),
                _group(CustomerAccountStrings.preferences, [
                  CustomerAccountAction(
                    icon: Icons.settings_outlined,
                    label: CustomerAccountStrings.settings,
                    onTap: () => _open(const CustomerSettingsScreen()),
                  ),
                  CustomerAccountAction(
                    icon: Icons.help_outline_rounded,
                    label: CustomerAccountStrings.help,
                    onTap: () => context.push('/help'),
                  ),
                ]),
                const SizedBox(height: AppSpacing.lg),
                CustomerAccountSurface(
                  child: CustomerAccountAction(
                    icon: Icons.logout_rounded,
                    label: CustomerAccountStrings.signOut,
                    destructive: true,
                    onTap: _signingOut ? null : _signOut,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _profile(UserModel profile) {
    final complete =
        profile.fullName.trim().length >= 2 &&
        isValidVietnamPhone(normalizeVietnamPhone(profile.phone ?? '')) &&
        profile.hasCustomerClassification;
    return CustomerAccountSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                final phone = Text(
                  profile.phone?.isNotEmpty == true
                      ? profile.phone!
                      : CustomerAccountStrings.missing,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CustomerAccountAvatar(
                          name: profile.fullName,
                          reference: profile.avatarUrl,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.fullName.trim().isEmpty
                                    ? CustomerAccountStrings.customer
                                    : profile.fullName,
                                style: AppTextStyles.headingMedium,
                              ),
                              if (!stacked) ...[
                                const SizedBox(height: AppSpacing.xs),
                                phone,
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: CustomerAccountStrings.edit,
                          onPressed: () =>
                              _open(CustomerProfileScreen(profile: profile)),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    if (stacked) ...[
                      const SizedBox(height: AppSpacing.sm),
                      phone,
                    ],
                  ],
                );
              },
            ),
            if (profile.hasCustomerClassification) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                profile.customerType == 'business'
                    ? '${CustomerClassificationStrings.business} · ${profile.businessName}'
                    : CustomerClassificationStrings.individual,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (!complete) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: () => _open(
                  profile.hasCustomerClassification
                      ? CustomerProfileScreen(profile: profile)
                      : const CustomerClassificationScreen(),
                ),
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text(CustomerAccountStrings.completeProfile),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _group(String title, List<Widget> actions) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CustomerAccountSurface(
          child: Column(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: 56, color: AppColors.border),
                actions[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
