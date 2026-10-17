import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:giaohang_design/giaohang_design.dart';

class DriverContactActionButton extends StatelessWidget {
  const DriverContactActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.filled,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = !enabled
        ? AppColors.border.withValues(alpha: 0.5)
        : filled
        ? AppColors.accent
        : AppColors.bgCard;
    final fg = !enabled
        ? AppColors.textMuted
        : filled
        ? AppColors.textOnAccent
        : AppColors.textPrimary;

    return Material(
      color: bg,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.md,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: filled || !enabled
                ? null
                : Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: AppSpacing.sm),
              Text(label, style: AppTextStyles.labelMedium.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> launchDriverTel(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'tel', path: _digitsOnly(phone));
  await _safeLaunch(context, uri, errorLabel: 'Không mở được ứng dụng gọi');
}

Future<void> launchDriverSms(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'sms', path: _digitsOnly(phone));
  await _safeLaunch(
    context,
    uri,
    errorLabel: 'Không mở được ứng dụng nhắn tin',
  );
}

String _digitsOnly(String phone) {
  final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
  return cleaned.isEmpty ? phone : cleaned;
}

Future<void> _safeLaunch(
  BuildContext context,
  Uri uri, {
  required String errorLabel,
}) async {
  try {
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorLabel)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorLabel)));
    }
  }
}
