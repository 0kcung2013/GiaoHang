import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../dashboard_strings.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key, required this.hasActiveDelivery});

  final bool hasActiveDelivery;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        icon: Icons.add_location_alt_rounded,
        label: DashboardStrings.createOrder,
        onTap: () => context.push('/customer/create-order'),
      ),
      _QuickActionData(
        icon: Icons.near_me_rounded,
        label: DashboardStrings.trackOrder,
        isLive: hasActiveDelivery,
        onTap: () => context.go('/customer-home?tab=tracking'),
      ),
      _QuickActionData(
        icon: Icons.receipt_long_rounded,
        label: DashboardStrings.orderHistory,
        onTap: () => context.go('/customer-home?tab=orders'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useTwoColumns = textScale > 1.35 || constraints.maxWidth < 340;
        final gap = AppSpacing.sm;
        final itemWidth = useTwoColumns
            ? (constraints.maxWidth - gap) / 2
            : (constraints.maxWidth - gap * 2) / 3;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                child: _QuickAction(data: action),
              ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.data});

  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: data.label,
      child: Material(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.xl,
            border: Border.all(color: AppColors.border),
          ),
          child: InkWell(
            onTap: data.onTap,
            splashColor: AppColors.accent.withValues(alpha: 0.1),
            highlightColor: AppColors.accent.withValues(alpha: 0.04),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.accentLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            data.icon,
                            color: AppColors.accent,
                            size: 20,
                          ),
                        ),
                        if (data.isLive)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.bgCard,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      data.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLive;
}
