import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';

const orderVisualHeaderKey = Key('order-visual-header');
const orderCreateActionKey = Key('order-create-action');

class OrderListHeader extends StatelessWidget {
  const OrderListHeader({
    super.key,
    required this.onCreateOrder,
    this.compact = false,
  });

  final VoidCallback onCreateOrder;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: compact,
      label: compact ? 'Tạo đơn hàng mới' : 'Theo dõi và quản lý đơn hàng',
      child: Container(
        key: orderVisualHeaderKey,
        height: compact ? double.infinity : 132,
        decoration: BoxDecoration(
          color: AppColors.bgWarm,
          borderRadius: AppRadius.xl,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.16)),
          boxShadow: AppShadow.subtle,
        ),
        child: ClipRRect(
          borderRadius: AppRadius.xl,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: Image.asset(
                  'assets/images/customer_orders_visual_header.png',
                  alignment: compact
                      ? const Alignment(0.58, 0)
                      : Alignment.centerRight,
                  fit: compact ? BoxFit.cover : BoxFit.fitHeight,
                  cacheWidth: compact ? 500 : 900,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: compact ? AppSpacing.sm : AppSpacing.xl2,
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.accent,
                        size: compact ? 46 : 72,
                      ),
                    ),
                  ),
                ),
              ),
              if (compact) ...[
                Positioned.fill(
                  child: Tooltip(
                    message: 'Tạo đơn mới',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: orderCreateActionKey,
                        onTap: onCreateOrder,
                        borderRadius: AppRadius.xl,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: IgnorePointer(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: AppShadow.subtle,
                      ),
                      child: const Icon(
                        Icons.add_location_alt_rounded,
                        color: AppColors.textOnAccent,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ] else
                Positioned(
                  left: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: Semantics(
                    button: true,
                    label: 'Tạo đơn hàng mới',
                    child: Tooltip(
                      message: 'Tạo đơn mới',
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: AppShadow.accentGlow,
                        ),
                        child: Material(
                          color: AppColors.accent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: orderCreateActionKey,
                            onTap: onCreateOrder,
                            child: const SizedBox.square(
                              dimension: 52,
                              child: Icon(
                                Icons.add_location_alt_rounded,
                                color: AppColors.textOnAccent,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
