import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class CustomerWalletPinTheme extends StatelessWidget {
  const CustomerWalletPinTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppTextStyles.headingMedium.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textOnAccent,
          minimumSize: const Size.fromHeight(52),
          textStyle: AppTextStyles.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 48),
          textStyle: AppTextStyles.labelMedium,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
    ),
    child: child,
  );
}
