import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../data/support_order_repository.dart';
import '../models/support_order_proof.dart';
import '../utils/support_order_proof_strings.dart';
import '../utils/support_order_ui.dart';
import '../widgets/support_order_proof_image.dart';

Future<void> showSupportOrderProofDialog(
  BuildContext context, {
  required SupportOrderProof proof,
  required SupportOrderRepository repository,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.all(AppSpacing.lg),
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 800),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SupportOrderProofStrings.stageLabel(proof.stage),
                        style: AppTextStyles.headingSmall,
                      ),
                      Text(
                        SupportOrderUi.formatDateTime(proof.capturedAt),
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: SupportOrderProofStrings.close,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ClipRect(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: SizedBox.expand(
                  child: SupportOrderProofImage(
                    loadUrl: () =>
                        repository.resolveDeliveryProofUrl(proof.storagePath),
                    semanticLabel: SupportOrderProofStrings.stageLabel(
                      proof.stage,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              SupportOrderProofStrings.zoom,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
