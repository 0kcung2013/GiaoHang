import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/risk_report.dart';

class RiskReporterProfileCard extends StatelessWidget {
  const RiskReporterProfileCard({required this.report, super.key});

  final RiskReport report;

  @override
  Widget build(BuildContext context) {
    final name = _displayName(report);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Người gửi báo cáo',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _ReporterAvatar(
                key: const Key('risk-reporter-profile-avatar'),
                name: name,
                imageUrl: report.reporterAvatarUrl,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _roleLabel(report.reporterRole),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_hasValue(report.reporterPhone)) ...[
            const SizedBox(height: AppSpacing.md),
            _ProfileLine(
              icon: Icons.phone_outlined,
              value: report.reporterPhone!,
              semanticLabel: 'Số điện thoại người gửi',
            ),
          ],
          if (_hasValue(report.reporterEmail)) ...[
            const SizedBox(height: AppSpacing.sm),
            _ProfileLine(
              icon: Icons.mail_outline_rounded,
              value: report.reporterEmail!,
              semanticLabel: 'Email người gửi',
            ),
          ],
        ],
      ),
    );
  }
}

class _ReporterAvatar extends StatelessWidget {
  const _ReporterAvatar({required this.name, this.imageUrl, super.key});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = _AvatarFallback(name: name);
    return Semantics(
      image: true,
      label: 'Ảnh đại diện của $name',
      child: Container(
        width: 56,
        height: 56,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.accentLight,
          shape: BoxShape.circle,
        ),
        child: _hasValue(imageUrl)
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                semanticLabel: 'Ảnh đại diện của $name',
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _initials(name),
        style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent),
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({
    required this.icon,
    required this.value,
    required this.semanticLabel,
  });

  final IconData icon;
  final String value;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticLabel: $value',
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SelectableText(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _displayName(RiskReport report) {
  final name = report.reporterName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return 'Người dùng chưa cập nhật tên';
}

String _roleLabel(RiskReporterRole role) => switch (role) {
  RiskReporterRole.customer => 'Khách hàng',
  RiskReporterRole.driver => 'Tài xế',
  RiskReporterRole.support => 'Nhân viên CSKH',
  RiskReporterRole.admin => 'Quản trị viên',
  RiskReporterRole.unknown => 'Người dùng',
};

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;
