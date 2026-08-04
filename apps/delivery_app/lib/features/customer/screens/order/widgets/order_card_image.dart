import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

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
    final uri = url == null || url.isEmpty ? null : Uri.tryParse(url);
    final canLoad =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

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
                ? Image.network(
                    url!,
                    key: orderCardImageKey,
                    fit: BoxFit.cover,
                    frameBuilder: (context, child, frame, loadedSynchronously) {
                      if (loadedSynchronously) return child;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          _OrderImagePlaceholder(category: category),
                          AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: AppDuration.normal,
                            curve: AppCurve.decelerate,
                            child: child,
                          ),
                        ],
                      );
                    },
                    errorBuilder: (_, _, _) =>
                        _OrderImagePlaceholder(category: category),
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
