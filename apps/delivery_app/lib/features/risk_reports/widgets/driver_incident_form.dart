import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../core/models/order_model.dart';
import '../../../core/utils/cargo_weight_strings.dart';
import '../controllers/risk_report_form_controller.dart';
import '../utils/risk_report_options.dart';
import '../utils/risk_report_strings.dart';
import 'risk_evidence_step.dart';
import 'risk_reason_step.dart';

/// Một form cho lý do, mô tả và ảnh; server quyết định quyền theo mốc nhận hàng.
class DriverIncidentForm extends StatelessWidget {
  const DriverIncidentForm({
    required this.order,
    required this.controller,
    required this.descriptionController,
    required this.onPickPhotos,
    required this.onCaptureLocation,
    super.key,
  });

  final OrderModel order;
  final RiskReportFormController controller;
  final TextEditingController descriptionController;
  final VoidCallback onPickPhotos;
  final VoidCallback onCaptureLocation;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final option = riskOptionFor(
      RiskReporterRole.driver,
      state.category,
      orderStatus: order.status,
      hasPickedUp: order.actualPickedUpAt != null,
    );
    return IgnorePointer(
      ignoring: state.isSubmitting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.trackingCode,
            style: AppTextStyles.mono.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          RiskReasonStep(
            role: RiskReporterRole.driver,
            selected: state.category,
            errorText: state.categoryError,
            onSelected: controller.selectCategory,
            orderStatus: order.status,
            hasPickedUp: order.actualPickedUpAt != null,
          ),
          if (option != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              option.description,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (controller.requestsCargoCancellation) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '${CargoWeightStrings.declaredWeight}: ${formatCargoWeightKg(order.itemWeightKg)}',
              style: AppTextStyles.labelMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              RiskReportStrings.cargoRequestHint,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          RiskEvidenceStep(
            descriptionController: descriptionController,
            photos: state.photos,
            latitude: state.latitude,
            longitude: state.longitude,
            locationAddress: state.locationAddress,
            locationRequired: false,
            descriptionError: state.descriptionError,
            photoError: state.photoError,
            locationError: state.locationError,
            onDescriptionChanged: controller.setDescription,
            onPickPhotos: onPickPhotos,
            onCaptureLocation: onCaptureLocation,
            compact: true,
            showLocation: false,
            onRemovePhoto: (index) => controller.setPhotos([
              for (var i = 0; i < state.photos.length; i++)
                if (i != index) state.photos[i],
            ]),
            photoRequired: controller.requestsCargoCancellation,
            callEvidenceRequired: controller.needsCallEvidence,
            descriptionLimit: controller.descriptionLimit,
            descriptionHint: controller.requestsCargoCancellation
                ? RiskReportStrings.cargoDescriptionHint
                : 'Điều gì đã xảy ra?',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            RiskReportStrings.reviewHint,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
