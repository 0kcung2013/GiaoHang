import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../services/return_route_quote_service.dart';

class SupportReturnQuoteCard extends StatelessWidget {
  const SupportReturnQuoteCard({
    required this.quote,
    required this.payer,
    super.key,
  });

  final ReturnRouteQuote quote;
  final ReturnFeePayer payer;

  @override
  Widget build(BuildContext context) => Container(
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
        _value('Thu nhập tài xế', _vnd(quote.suggestedFee)),
        _value(
          'Khách thanh toán',
          _vnd(payer == ReturnFeePayer.customer ? quote.suggestedFee : 0),
        ),
      ],
    ),
  );

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
