import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

enum ArrivalContactAction { call, chat }

Future<ArrivalContactAction?> showArrivalContactSheet({
  required BuildContext context,
  required String contactLabel,
  required String contactName,
  required String? phone,
  required String address,
}) {
  final normalizedPhone = phone?.trim() ?? '';
  return showModalBottomSheet<ArrivalContactAction>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: AppRadius.full,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Liên hệ $contactLabel',
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            contactName,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _ContactChoice(
                  icon: Icons.call_rounded,
                  label: 'Gọi điện',
                  detail: normalizedPhone.isEmpty
                      ? 'Chưa có số điện thoại'
                      : normalizedPhone,
                  color: AppColors.success,
                  enabled: normalizedPhone.isNotEmpty,
                  onTap: () =>
                      Navigator.pop(context, ArrivalContactAction.call),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ContactChoice(
                  icon: Icons.forum_rounded,
                  label: 'Nhắn tin',
                  detail: 'Câu trả lời nhanh',
                  color: AppColors.info,
                  onTap: () =>
                      Navigator.pop(context, ArrivalContactAction.chat),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ContactChoice extends StatelessWidget {
  const _ContactChoice({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled ? color : AppColors.textMuted;
    return Material(
      color: enabled ? color.withValues(alpha: 0.08) : AppColors.bgLight,
      borderRadius: AppRadius.lg,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.lg,
        child: Container(
          constraints: const BoxConstraints(minHeight: 122),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lg,
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.24) : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 28),
              const SizedBox(height: AppSpacing.xl),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: enabled ? AppColors.textPrimary : foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
