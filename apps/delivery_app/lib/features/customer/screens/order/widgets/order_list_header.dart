import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

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
    if (compact) {
      return _CompactOrderHeader(onCreateOrder: onCreateOrder);
    }

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
                  fit: compact ? BoxFit.contain : BoxFit.fitHeight,
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
                Positioned(
                  left: AppSpacing.lg,
                  top: AppSpacing.lg,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GIAOHÀNG',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Đơn của bạn',
                          style: AppTextStyles.displayMedium.copyWith(
                            color: AppColors.primary,
                            fontSize: 26,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Theo dõi và quản lý mọi chuyến giao',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  child: IgnorePointer(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: AppRadius.xl,
                            boxShadow: AppShadow.accentGlow,
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: AppColors.textOnAccent,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Tạo đơn',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

class _CompactOrderHeader extends StatelessWidget {
  const _CompactOrderHeader({required this.onCreateOrder});

  final VoidCallback onCreateOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: orderVisualHeaderKey,
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Đơn đã mua',
              style: AppTextStyles.headingLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tạo đơn mới',
            onPressed: onCreateOrder,
            icon: const Icon(Icons.add_rounded),
            color: AppColors.accent,
            iconSize: 28,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            key: orderCreateActionKey,
          ),
        ],
      ),
    );
  }
}
