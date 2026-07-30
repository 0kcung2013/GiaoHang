import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../dashboard_strings.dart';

class DashboardServicePromise extends StatelessWidget {
  const DashboardServicePromise({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DashboardStrings.servicePromiseTitle,
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.xl,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadow.subtle,
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PromiseItem(
                  icon: Icons.payments_outlined,
                  label: DashboardStrings.transparentPrice,
                ),
              ),
              _PromiseDivider(),
              Expanded(
                child: _PromiseItem(
                  icon: Icons.verified_user_outlined,
                  label: DashboardStrings.verifiedDriver,
                ),
              ),
              _PromiseDivider(),
              Expanded(
                child: _PromiseItem(
                  icon: Icons.route_outlined,
                  label: DashboardStrings.liveTracking,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PromiseItem extends StatelessWidget {
  const _PromiseItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromiseDivider extends StatelessWidget {
  const _PromiseDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 52,
      margin: const EdgeInsets.only(
        left: AppSpacing.xs,
        right: AppSpacing.xs,
        top: AppSpacing.xs,
      ),
      color: AppColors.border,
    );
  }
}
