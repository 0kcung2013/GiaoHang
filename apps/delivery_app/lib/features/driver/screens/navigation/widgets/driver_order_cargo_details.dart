import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/order_cargo_utils.dart';
import '../../../../../core/widgets/stored_media_image.dart';
import '../../home/widgets/driver_order_offer_summary.dart';

class DriverOrderCargoDetails extends StatelessWidget {
  const DriverOrderCargoDetails({super.key, required this.order});
  final OrderModel order;

  Widget _photo() => StoredMediaImage(
    storedValue: order.itemImageUrl!.trim(),
    fit: BoxFit.contain,
    fallback: const Icon(
      Icons.broken_image_rounded,
      color: AppColors.textSecondary,
      size: 32,
    ),
  );

  void _openPhoto(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: AppColors.primary,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(child: Center(child: _photo())),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: IconButton(
                tooltip: DriverOrderPresentationStrings.closePhoto,
                color: AppColors.textOnDark,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.itemImageUrl?.trim().isNotEmpty == true) ...[
            Semantics(
              label: DriverOrderPresentationStrings.viewPhoto,
              button: true,
              child: Material(
                color: AppColors.bgLight,
                borderRadius: AppRadius.md,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openPhoto(context),
                  child: SizedBox(width: 88, height: 88, child: _photo()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cargoNameOrFallback(order),
                  style: AppTextStyles.headingMedium,
                ),
                if (order.itemCategory?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    cargoCategoryLabel(order.itemCategory),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      if (order.itemDescription?.trim().isNotEmpty == true) ...[
        const SizedBox(height: AppSpacing.md),
        Text(order.itemDescription!.trim(), style: AppTextStyles.bodyMedium),
      ],
    ],
  );
}
