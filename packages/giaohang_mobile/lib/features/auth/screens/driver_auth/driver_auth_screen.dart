import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';

import 'driver_auth_strings.dart';
import 'widgets/driver_auth_brand.dart';
import 'widgets/driver_login_form.dart';
import 'widgets/driver_register_form.dart';

/// Separate routes for driver login and KYC, without a role selector.
class DriverAuthScreen extends StatelessWidget {
  const DriverAuthScreen({super.key, this.register = false});
  final bool register;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: AppColors.bgCard,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      if (register) ...[
                        IconButton(
                          tooltip: DriverAuthStrings.backToLogin,
                          onPressed: () => context.go('/login'),
                          color: AppColors.textPrimary,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: register
                            ? Text(
                                DriverAuthStrings.registerTitle,
                                style: AppTextStyles.headingSmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : const DriverAuthBrand(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: register
                      ? const DriverRegisterForm()
                      : const DriverLoginForm(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
