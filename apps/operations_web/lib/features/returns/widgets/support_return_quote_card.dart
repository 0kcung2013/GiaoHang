import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../services/return_route_quote_service.dart';

class SupportReturnQuoteCard extends StatelessWidget {
  const SupportReturnQuoteCard({
    required this.quote,
    required this.payer,
    required this.deliveryFee,
    super.key,
  });

  final ReturnRouteQuote quote;
  final ReturnFeePayer payer;
  final int deliveryFee;

  @override
  Widget build(BuildContext context) {
    final returnFee = OrderReturnPricingPolicy.calculateReturnFee(deliveryFee);
    final totalDriverEarning =
        OrderReturnPricingPolicy.calculateTotalDriverEarning(deliveryFee);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
      ),
      child: Wrap(
        spacing: AppSpacing.xl,
        runSpacing: AppSpacing.sm,
        children: [
          _value(
            'Quãng hoàn',
            '${(quote.distanceMeters / 1000).toStringAsFixed(1)} km',
          ),
          _value('Dự kiến', '${(quote.durationSeconds / 60).ceil()} phút'),
          _value('Cước giao gốc', _vnd(deliveryFee)),
          _value('Phí hoàn hàng (50%)', _vnd(returnFee)),
          _value('Tổng tài xế nhận', _vnd(totalDriverEarning)),
          _value(
            'Khách trả thêm',
            _vnd(payer == ReturnFeePayer.customer ? returnFee : 0),
          ),
        ],
      ),
    );
  }

  Widget _value(String label, String value) => SizedBox(
    width: 135,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTextStyles.labelMedium),
      ],
    ),
  );
}

String _vnd(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${buffer.toString()} đ';
}
