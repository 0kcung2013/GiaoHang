import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../driver_auth_strings.dart';

class DriverAuthBrand extends StatelessWidget {
  const DriverAuthBrand({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${DriverAuthStrings.brand} · ${DriverAuthStrings.driver}',
    child: ExcludeSemantics(
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_rounded,
            color: AppColors.accent,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              DriverAuthStrings.brand,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
