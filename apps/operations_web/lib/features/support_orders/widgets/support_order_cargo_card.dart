import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../core/widgets/stored_media_image.dart';
import '../utils/support_order_information_strings.dart';
import '../utils/support_order_ui.dart';
import 'support_order_information_components.dart';

class SupportOrderCargoCard extends StatelessWidget {
  const SupportOrderCargoCard({required this.order, super.key});
  final RiskOrderSummary order;

  Widget _photo() => StoredMediaImage(
    storedValue: order.itemImageUrl,
    fit: BoxFit.contain,
    semanticLabel: SupportOrderInformationStrings.cargoPhoto,
    fallback: const Center(
      child: Icon(
        Icons.inventory_2_rounded,
        color: AppColors.textSecondary,
        size: 32,
      ),
    ),
  );

  void _openPhoto(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: SupportOrderInformationStrings.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Expanded(
              child: InteractiveViewer(child: Center(child: _photo())),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SupportOrderInfoSection(
    title: SupportOrderInformationStrings.cargo,
    icon: Icons.inventory_2_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          order.itemName?.trim().isNotEmpty == true
              ? order.itemName!
              : SupportOrderInformationStrings.noCargoName,
          style: AppTextStyles.headingMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        SupportOrderInfoFacts(
          children: [
            SupportOrderInfoFact(
              label: SupportOrderInformationStrings.weight,
              value: formatCargoWeightKg(order.itemWeightKg),
            ),
            SupportOrderInfoFact(
              label: SupportOrderInformationStrings.category,
              value: SupportOrderUi.cargoCategoryLabel(order.itemCategory),
            ),
          ],
        ),
        if (order.itemDescription?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.lg),
          SupportOrderInfoFact(
            label: SupportOrderInformationStrings.description,
            value: order.itemDescription,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (order.itemImageUrl?.trim().isNotEmpty == true)
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: SupportOrderInformationStrings.viewPhoto,
              child: Material(
                color: AppColors.bgCard,
                borderRadius: AppRadius.md,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openPhoto(context),
                  child: SizedBox(width: 160, height: 120, child: _photo()),
                ),
              ),
            ),
          )
        else
          Text(
            SupportOrderInformationStrings.noCargoPhoto,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        if (order.note?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.lg),
          SupportOrderInfoFact(
            label: SupportOrderInformationStrings.notes,
            value: order.note,
          ),
        ],
      ],
    ),
  );
}
