import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/utils/delivery_fee_calculator.dart';
import '../utils/create_order_formatters.dart';
import '../utils/delivery_eta_strings.dart';
import '../utils/traffic_demo_strings.dart';

class OrderQuoteStep extends StatelessWidget {
  const OrderQuoteStep({
    super.key,
    required this.quote,
    required this.pickupAddress,
    required this.deliveryAddress,
    this.isTrafficDemo = false,
  });

  final DeliveryFeeEstimate quote;
  final String pickupAddress;
  final String deliveryAddress;
  final bool isTrafficDemo;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            AppSpacing.xl2,
          ),
          children: [
            _PriceCard(quote: quote, isTrafficDemo: isTrafficDemo),
            const SizedBox(height: AppSpacing.lg),
            _RouteCard(
              pickupAddress: pickupAddress,
              deliveryAddress: deliveryAddress,
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.07),
                borderRadius: AppRadius.lg,
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: AppColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Mức phí này sẽ được giữ nguyên khi xác nhận đơn.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.quote, required this.isTrafficDemo});

  final DeliveryFeeEstimate quote;
  final bool isTrafficDemo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl2,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: AppRadius.lg,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phí giao hàng',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatDeliveryFee(quote.deliveryFee),
                        maxLines: 1,
                        style: AppTextStyles.displayMedium.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _QuoteMetrics(quote: quote),
          const SizedBox(height: AppSpacing.sm),
          Text(
            DeliveryEtaStrings.afterAssignment,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (isTrafficDemo) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              TrafficDemoStrings.forecastNote,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuoteMetrics extends StatelessWidget {
  const _QuoteMetrics({required this.quote});

  final DeliveryFeeEstimate quote;

  @override
  Widget build(BuildContext context) {
    final distance = _Metric(
      icon: Icons.route_rounded,
      label: 'Quãng đường',
      value: '${quote.distanceKm.toStringAsFixed(1)} km',
    );
    final eta = _Metric(
      icon: Icons.schedule_rounded,
      label: DeliveryEtaStrings.estimatedDelivery,
      value: DeliveryEtaStrings.waitingForDriver,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        if (constraints.maxWidth / textScale < 280) {
          return Column(
            children: [
              distance,
              const SizedBox(height: AppSpacing.sm),
              eta,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: distance),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: eta),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.info, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
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

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.pickupAddress,
    required this.deliveryAddress,
  });

  final String pickupAddress;
  final String deliveryAddress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _Stop(
            icon: Icons.storefront_rounded,
            label: 'Điểm lấy',
            value: pickupAddress,
            color: AppColors.markerPickup,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(color: AppColors.border),
          ),
          _Stop(
            icon: Icons.location_on_rounded,
            label: 'Điểm giao',
            value: deliveryAddress,
            color: AppColors.markerDrop,
          ),
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(color: color),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
