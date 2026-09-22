import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/risk_report_strings.dart';
import '../models/risk_report.dart';

class RiskRelatedParties extends StatelessWidget {
  const RiskRelatedParties({required this.report, super.key});

  final RiskReport report;

  @override
  Widget build(BuildContext context) {
    final order = report.order;
    RiskContact? contactFor(String? id, RiskContact? contact) {
      if (contact != null || id == null || id != report.reportedBy) {
        return contact;
      }
      return RiskContact(
        name: report.reporterName,
        phone: report.reporterPhone,
        email: report.reporterEmail,
        avatarUrl: report.reporterAvatarUrl,
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            RiskReportStrings.relatedParties,
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Party(
            label: RiskReportStrings.orderingCustomer,
            icon: Icons.person_rounded,
            contact: contactFor(order.customerId, order.customer),
            isReporter: order.customerId == report.reportedBy,
          ),
          const Divider(height: AppSpacing.xl2, color: AppColors.border),
          _Party(
            label: RiskReportStrings.assignedDriver,
            icon: Icons.local_shipping_rounded,
            contact: contactFor(order.driverId, order.driver),
            isReporter: order.driverId == report.reportedBy,
            emptyLabel: order.driverId == null
                ? RiskReportStrings.noDriver
                : RiskReportStrings.missingProfile,
            showAccessHint: order.driverId != null,
          ),
          const Divider(height: AppSpacing.xl2, color: AppColors.border),
          _Party(
            label: RiskReportStrings.recipient,
            icon: Icons.location_on_rounded,
            contact: RiskContact(
              name: order.recipientName,
              phone: order.recipientPhone,
            ),
            showAccessHint: false,
          ),
        ],
      ),
    );
  }
}

class _Party extends StatelessWidget {
  const _Party({
    required this.label,
    required this.icon,
    this.contact,
    this.isReporter = false,
    this.emptyLabel = RiskReportStrings.missingProfile,
    this.showAccessHint = true,
  });

  final String label;
  final IconData icon;
  final RiskContact? contact;
  final bool isReporter;
  final String emptyLabel;
  final bool showAccessHint;

  @override
  Widget build(BuildContext context) {
    final name = contact?.name?.trim();
    final phone = contact?.phone?.trim();
    final email = contact?.email?.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.bgLight,
            borderRadius: AppRadius.md,
          ),
          child: Icon(icon, size: 20, color: AppColors.accent),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(
                name == null || name.isEmpty ? emptyLabel : name,
                style: AppTextStyles.labelMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(
                phone == null || phone.isEmpty
                    ? RiskReportStrings.missingPhone
                    : phone,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (email != null && email.isNotEmpty)
                SelectableText(email, style: AppTextStyles.bodySmall),
              if (isReporter) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  RiskReportStrings.reporterMarker,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.info,
                  ),
                ),
              ],
              if (contact == null && showAccessHint) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  RiskReportStrings.restrictedProfile,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
