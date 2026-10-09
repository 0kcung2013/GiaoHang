import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../widgets/auth_strings.dart';

class RegisterRolePicker extends StatelessWidget {
  const RegisterRolePicker({
    super.key,
    required this.role,
    required this.onChanged,
  });
  final String role;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final customer = _RoleTile(
        label: AuthStrings.customer,
        hint: AuthStrings.customerHint,
        icon: Icons.inventory_2_outlined,
        selected: role == 'customer',
        onTap: () => onChanged('customer'),
      );
      final driver = _RoleTile(
        label: AuthStrings.driver,
        hint: AuthStrings.driverHint,
        icon: Icons.delivery_dining_rounded,
        selected: role == 'driver',
        onTap: () => onChanged('driver'),
      );
      if (constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(15) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            customer,
            const SizedBox(height: AppSpacing.sm),
            driver,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: customer),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: driver),
        ],
      );
    },
  );
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.label,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String hint;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDuration.normal;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label. $hint',
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: duration,
        constraints: const BoxConstraints(minHeight: 128),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentLight : AppColors.bgLight,
          borderRadius: AppRadius.lg,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.lg,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.lg,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 27, color: AppColors.primary),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: duration,
                        child: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          key: ValueKey(selected),
                          size: 19,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    hint,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
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
}
