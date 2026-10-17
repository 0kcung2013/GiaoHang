import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/widgets/stored_media_image.dart';

const orderCardImageKey = Key('order-card-image');
const orderCardImagePlaceholderKey = Key('order-card-image-placeholder');

class OrderCardImage extends StatelessWidget {
  const OrderCardImage({
    super.key,
    required this.imageUrl,
    required this.category,
    this.size = 84,
  });

  final String? imageUrl;
  final String? category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final canLoad = url != null && url.isNotEmpty;

    return Semantics(
      image: true,
      label: 'Ảnh hàng hoá',
      child: ClipRRect(
        borderRadius: AppRadius.lg,
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.14),
              ),
            ),
            child: canLoad
                ? StoredMediaImage(
                    storedValue: url,
                    imageKey: orderCardImageKey,
                    fit: BoxFit.cover,
                    fallback: _OrderImagePlaceholder(category: category),
                  )
                : _OrderImagePlaceholder(category: category),
          ),
        ),
      ),
    );
  }
}

class _OrderImagePlaceholder extends StatelessWidget {
  const _OrderImagePlaceholder({required this.category});

  final String? category;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: orderCardImagePlaceholderKey,
      color: AppColors.accentLight,
      child: Stack(
        children: [
          Center(
            child: Icon(
              _categoryIcon(category),
              color: AppColors.accent,
              size: 32,
            ),
          ),
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.28),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(String? category) {
  return switch (category) {
    'food' => Icons.restaurant_rounded,
    'document' => Icons.description_rounded,
    'fragile' => Icons.wine_bar_rounded,
    'grocery' => Icons.shopping_bag_rounded,
    'parcel' => Icons.inventory_2_rounded,
    _ => Icons.local_mall_rounded,
  };
}
