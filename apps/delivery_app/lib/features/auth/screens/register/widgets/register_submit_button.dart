import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../widgets/auth_strings.dart';

class RegisterSubmitButton extends StatelessWidget {
  const RegisterSubmitButton({
    super.key,
    required this.driver,
    required this.busy,
    required this.onPressed,
  });
  final bool driver;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnDark,
        disabledBackgroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.textOnDark,
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        textStyle: AppTextStyles.labelLarge.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              busy
                  ? AuthStrings.registering
                  : driver
                  ? AuthStrings.driverNext
                  : AuthStrings.register,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppDuration.fast,
            child: busy
                ? Semantics(
                    label: AuthStrings.registering,
                    liveRegion: true,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: MediaQuery.disableAnimationsOf(context)
                          ? const Icon(
                              Icons.hourglass_top_rounded,
                              color: AppColors.accent,
                            )
                          : const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                    ),
                  )
                : Container(
                    key: const ValueKey('register-arrow'),
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: AppRadius.sm,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
