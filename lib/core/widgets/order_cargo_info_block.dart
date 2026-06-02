import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/order_model.dart';
import '../utils/order_cargo_utils.dart';

class OrderCargoInfoBlock extends StatelessWidget {
  const OrderCargoInfoBlock({
    super.key,
    required this.order,
    this.compact = false,
    this.showEmptyState = false,
  });

  final OrderModel order;
  final bool compact;
  final bool showEmptyState;

  @override
  Widget build(BuildContext context) {
    if (!hasCargoInfo(order) && !showEmptyState) {
      return const SizedBox.shrink();
    }

    final imageUrl = order.itemImageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        color: compact ? AppColors.bgLight : AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CargoImage(url: hasImage ? imageUrl : null, compact: compact),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cargoNameOrFallback(order),
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (compact
                              ? AppTextStyles.labelMedium
                              : AppTextStyles.labelLarge)
                          .copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  cargoCategoryLabel(order.itemCategory),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((order.itemDescription ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    order.itemDescription!.trim(),
                    maxLines: compact ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CargoImage extends StatelessWidget {
  const _CargoImage({required this.url, required this.compact});

  final String? url;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 48.0 : 72.0;
    final imageUrl = url;

    return ClipRRect(
      borderRadius: AppRadius.md,
      child: Container(
        width: size,
        height: size,
        color: AppColors.accentLight,
        child: imageUrl == null
            ? const Icon(
                Icons.inventory_2_rounded,
                color: AppColors.accent,
                size: 24,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_rounded,
                  color: AppColors.textMuted,
                  size: 24,
                ),
              ),
      ),
    );
  }
}
