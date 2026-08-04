import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class OperationsLoginContent extends StatelessWidget {
  const OperationsLoginContent({
    required this.compact,
    required this.accountController,
    required this.passwordController,
    required this.loading,
    required this.obscurePassword,
    required this.error,
    required this.onTogglePassword,
    required this.onSignIn,
    super.key,
  });

  final bool compact;
  final TextEditingController accountController;
  final TextEditingController passwordController;
  final bool loading;
  final bool obscurePassword;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.xl : AppSpacing.xl5,
            vertical: AppSpacing.xl3,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: EdgeInsets.all(
                compact ? AppSpacing.xl2 : AppSpacing.xl4,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: AppRadius.xl2,
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadow.elevated,
              ),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (compact) ...[
                      const _CompactBrand(),
                      const SizedBox(height: AppSpacing.xl3),
                    ],
                    Text(
                      'Chào mừng trở lại',
                      style: AppTextStyles.displayMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Đăng nhập Trung tâm vận hành dành cho Admin và CSKH.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl3),
                    const _FieldLabel(text: 'Tài khoản hoặc email'),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      key: const Key('operations-account-field'),
                      controller: accountController,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        hintText: 'admin hoặc ten@congty.vn',
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _FieldLabel(text: 'Mật khẩu'),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      key: const Key('operations-password-field'),
                      controller: passwordController,
                      autofillHints: const [AutofillHints.password],
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onSignIn(),
                      decoration: _inputDecoration(
                        hintText: 'Nhập mật khẩu',
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          tooltip: obscurePassword
                              ? 'Hiện mật khẩu'
                              : 'Ẩn mật khẩu',
                          onPressed: onTogglePassword,
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: AppDuration.fast,
                      child: error == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.md,
                              ),
                              child: _ErrorMessage(message: error!),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.xl2),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('operations-login-button'),
                        onPressed: loading ? null : onSignIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.textOnAccent,
                          disabledBackgroundColor: AppColors.accent.withValues(
                            alpha: 0.55,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.md,
                          ),
                          elevation: 0,
                          textStyle: AppTextStyles.labelLarge,
                        ),
                        child: loading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.textOnAccent,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Đăng nhập'),
                                  SizedBox(width: AppSpacing.sm),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            'Khu vực nội bộ · Kết nối được bảo mật',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
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

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
      prefixIcon: Icon(prefixIcon, color: AppColors.textSecondary, size: 21),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.bgLight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: AppColors.borderFocus, width: 1.5),
      ),
      border: const OutlineInputBorder(borderRadius: AppRadius.md),
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.md,
          ),
          child: const Icon(
            Icons.local_shipping_outlined,
            color: AppColors.textOnAccent,
            size: 23,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          'GIAOHANG',
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.primary,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
