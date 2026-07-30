import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/utils/delivery_pricing_policy.dart';
import '../utils/create_order_formatters.dart';
import '../utils/order_form_data.dart';

class DeliveryQuoteCard extends StatelessWidget {
  const DeliveryQuoteCard({super.key, required this.data});

  final OrderFormData data;

  @override
  Widget build(BuildContext context) {
    final fee = data.feeBreakdown;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuoteHeader(total: fee.total),
          const SizedBox(height: AppSpacing.lg),
          _EtaPanel(data: data),
          const SizedBox(height: AppSpacing.lg),
          _RouteMeta(data: data),
          const SizedBox(height: AppSpacing.lg),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'CHI TIẾT CƯỚC PHÍ',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _FeeBreakdown(fee: fee),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: AppRadius.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Giá được chốt theo lộ trình, làm tròn 1.000đ và không có phụ phí ẩn.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteHeader extends StatelessWidget {
  const _QuoteHeader({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: AppRadius.md,
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: AppColors.accent,
            size: 21,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tổng phí giao hàng',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Báo giá cho dịch vụ tiêu chuẩn',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          formatDeliveryFee(total),
          style: AppTextStyles.headingLarge.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _EtaPanel extends StatelessWidget {
  const _EtaPanel({required this.data});

  final OrderFormData data;

  @override
  Widget build(BuildContext context) {
    final eta = data.deliveryEta;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.md,
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppColors.accent,
              size: 23,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Giao hàng dự kiến',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (eta.isPeakHour) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 3,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: AppRadius.full,
                        ),
                        child: Text(
                          'Giờ cao điểm',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textOnAccent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  eta.rangeLabel,
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tính từ khi tài xế nhận hàng · đã gồm thời gian bàn giao',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMeta extends StatelessWidget {
  const _RouteMeta({required this.data});

  final OrderFormData data;

  @override
  Widget build(BuildContext context) {
    final eta = data.deliveryEta;
    final routeBasis = eta.usedRouteDuration
        ? 'OSRM + hiệu chỉnh đô thị'
        : 'Hiệu chỉnh theo vận tốc đô thị';

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _MetaChip(
          icon: Icons.route_outlined,
          label: '${data.distanceKm.toStringAsFixed(1)} km đường bộ',
        ),
        _MetaChip(icon: Icons.tune_rounded, label: routeBasis),
        const _MetaChip(
          icon: Icons.person_search_outlined,
          label: 'Tìm tài xế tối đa 15 phút',
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.07),
        borderRadius: AppRadius.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.info),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeBreakdown extends StatelessWidget {
  const _FeeBreakdown({required this.fee});

  final DeliveryFeeBreakdown fee;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FeeLine(
          label:
              'Phí mở đơn · đã gồm ${_formatKm(fee.includedDistanceKm)} km đầu',
          value: fee.baseFee,
        ),
        if (fee.standardBillableKm > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _FeeLine(
            label:
                '${_formatKm(fee.standardBillableKm)} km tiếp theo × ${formatDeliveryFee(DeliveryPricingPolicy.standardPerKm)}',
            value: fee.standardDistanceFee,
          ),
        ],
        if (fee.longBillableKm > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _FeeLine(
            label:
                '${_formatKm(fee.longBillableKm)} km đường dài × ${formatDeliveryFee(DeliveryPricingPolicy.longDistancePerKm)}',
            value: fee.longDistanceFee,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: AppSpacing.md),
        _FeeLine(label: 'Tổng cộng', value: fee.total, emphasized: true),
      ],
    );
  }
}

class _FeeLine extends StatelessWidget {
  const _FeeLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? AppTextStyles.labelLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          )
        : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: AppSpacing.md),
        Text(
          formatDeliveryFee(value),
          style: style.copyWith(
            color: emphasized ? AppColors.accent : AppColors.textPrimary,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _formatKm(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
