import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

class DemoAutofillButton extends StatelessWidget {
  const DemoAutofillButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tự động điền dữ liệu demo',
      child: Material(
        color: AppColors.accentLight,
        borderRadius: AppRadius.full,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.full,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_fix_high_rounded,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Điền dữ liệu demo',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
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
