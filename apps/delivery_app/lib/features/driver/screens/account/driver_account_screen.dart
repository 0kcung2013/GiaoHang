import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../core/services/auth_service.dart';
import '../home/widgets/driver_home_layout.dart';
import 'dialogs/driver_profile_change_request_sheet.dart';
import 'models/driver_account_view_data.dart';
import 'providers/driver_profile_change_providers.dart';
import 'utils/driver_account_strings.dart';
import 'widgets/driver_account_logout_sheet.dart';
import 'widgets/driver_account_profile_hero.dart';
import 'widgets/driver_account_sections.dart';
import 'widgets/driver_profile_change_action.dart';
import 'widgets/driver_profile_change_status_card.dart';

class DriverAccountScreen extends ConsumerStatefulWidget {
  const DriverAccountScreen({super.key});

  @override
  ConsumerState<DriverAccountScreen> createState() =>
      _DriverAccountScreenState();
}

class _DriverAccountScreenState extends ConsumerState<DriverAccountScreen> {
  bool _isSigningOut = false;

  Future<void> _confirmAndSignOut() async {
    if (_isSigningOut) return;
    final confirmed = await showDriverAccountLogoutSheet(context);
    if (!confirmed || !mounted) return;

    setState(() => _isSigningOut = true);
    try {
      await AuthService().signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(DriverAccountStrings.signOutError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      );
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(currentDriverAccountProfileProvider);
    ref.invalidate(currentDriverProfileChangeProvider);
    await ref.read(currentDriverAccountProfileProvider.future);
  }

  Future<void> _openProfileChange(
    DriverAccountViewData profile, {
    DriverProfileChangeRequest? request,
  }) async {
    await showDriverProfileChangeRequestSheet(
      context,
      profile: profile,
      repository: ref.read(driverProfileChangeRepositoryProvider),
      request: request,
    );
    ref.invalidate(currentDriverProfileChangeProvider);
    ref.invalidate(currentDriverAccountProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return ColoredBox(
      color: AppColors.bgLight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = DriverHomeLayout.fromWidth(constraints.maxWidth);
          if (user == null) return _SignedOutState(layout: layout);

          final driverAsync = ref.watch(currentDriverAccountProfileProvider);
          final requestAsync = ref.watch(currentDriverProfileChangeProvider);
          final data = DriverAccountViewData.from(
            user: user,
            driver: driverAsync.valueOrNull,
          );

          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.bgCard,
            onRefresh: _refresh,
            child: SingleChildScrollView(
              key: const PageStorageKey<String>('driver-account-scroll'),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                layout.horizontalPadding,
                layout.topPadding,
                layout.horizontalPadding,
                AppSpacing.xl4,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    children: [
                      DriverAccountProfileHero(
                        data: data,
                        isLoading: driverAsync.isLoading,
                      ),
                      if (driverAsync.hasError) ...[
                        const SizedBox(height: AppSpacing.md),
                        DriverAccountLoadNotice(
                          onRetry: () => ref.invalidate(
                            currentDriverAccountProfileProvider,
                          ),
                        ),
                      ],
                      SizedBox(height: layout.sectionGap),
                      DriverVehicleCard(data: data),
                      SizedBox(height: layout.sectionGap),
                      DriverVerificationCard(data: data),
                      SizedBox(height: layout.sectionGap),
                      DriverContactCard(data: data),
                      if (requestAsync.valueOrNull case final request?) ...[
                        SizedBox(height: layout.sectionGap),
                        DriverProfileChangeStatusCard(
                          request: request,
                          onView: () =>
                              _openProfileChange(data, request: request),
                        ),
                      ],
                      SizedBox(height: layout.sectionGap),
                      DriverProfileChangeAction(
                        request: requestAsync.valueOrNull,
                        onCreate: () => _openProfileChange(data),
                        onView: (request) =>
                            _openProfileChange(data, request: request),
                      ),
                      const SizedBox(height: AppSpacing.xl2),
                      DriverAccountLogoutButton(
                        isSigningOut: _isSigningOut,
                        onTap: _isSigningOut ? null : _confirmAndSignOut,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState({required this.layout});

  final DriverHomeLayout layout;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        layout.horizontalPadding,
        layout.topPadding,
        layout.horizontalPadding,
        AppSpacing.xl4,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl2),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.xl,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.subtle,
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: AppRadius.lg,
                  ),
                  child: const Icon(
                    Icons.lock_person_outlined,
                    color: AppColors.warning,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  DriverAccountStrings.loginRequired,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  DriverAccountStrings.loginRequiredMessage,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
