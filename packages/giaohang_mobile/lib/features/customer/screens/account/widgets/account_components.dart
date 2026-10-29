import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/widgets/stored_media_image.dart';
import '../constants/customer_account_strings.dart';

class CustomerAccountSurface extends StatelessWidget {
  const CustomerAccountSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class CustomerAccountAction extends StatelessWidget {
  const CustomerAccountAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.bgCard,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      minVerticalPadding: AppSpacing.md,
      leading: Icon(
        icon,
        color: destructive ? AppColors.error : AppColors.primary,
      ),
      title: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          color: destructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: AppTextStyles.bodySmall),
      trailing: destructive
          ? null
          : const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
      onTap: onTap,
    ),
  );
}

class CustomerAccountAvatar extends StatelessWidget {
  const CustomerAccountAvatar({
    super.key,
    required this.name,
    this.reference,
    this.size = 64,
  });
  final String name;
  final String? reference;
  final double size;
  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? 'KH'
        : parts.length == 1
        ? parts.first.characters.first.toUpperCase()
        : (parts.first.characters.first + parts.last.characters.first)
              .toUpperCase();
    final fallback = ColoredBox(
      color: AppColors.accentLight,
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.headingLarge.copyWith(color: AppColors.accent),
        ),
      ),
    );
    return Semantics(
      label: CustomerAccountStrings.profile,
      image: true,
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: StoredMediaImage(
            storedValue: reference,
            fallback: fallback,
            width: size,
            height: size,
          ),
        ),
      ),
    );
  }
}

class CustomerAccountState extends StatelessWidget {
  const CustomerAccountState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl2),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.person_outline_rounded,
          color: AppColors.textSecondary,
          size: 32,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          message,
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: const Text(CustomerAccountStrings.retry),
          ),
      ],
    ),
  );
}

Future<bool> confirmCustomerAccountAction(
  BuildContext context, {
  required String title,
  required String confirm,
  String? message,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTextStyles.headingMedium),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(message, style: AppTextStyles.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textOnAccent,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirm),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(CustomerAccountStrings.cancel),
              ),
            ],
          ),
        ),
      ),
    ) ??
    false;
