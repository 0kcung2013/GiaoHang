import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/order_cargo_utils.dart';
import 'order_print_label_strings.dart';

const orderShippingLabelKey = Key('order-shipping-label');
const orderShippingLabelBarcodeKey = Key('order-shipping-label-barcode');

class OrderShippingLabel extends StatelessWidget {
  const OrderShippingLabel({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final trackingCode = _fallback(
      order.trackingCode,
      fallback: '#${order.id.substring(0, math.min(order.id.length, 8))}',
    );
    final collectionAmount = order.receiverCollectionAmount > 0
        ? order.receiverCollectionAmount
        : order.codCollectionAmount;

    return Semantics(
      label:
          '${OrderPrintLabelStrings.previewSemantics}, mã $trackingCode, '
          'giao cho ${_fallback(order.recipientName)}',
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          key: orderShippingLabelKey,
          color: AppColors.bgCard,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: 320,
              height: 480,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  border: Border.all(color: AppColors.textPrimary, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LabelHeader(
                        trackingCode: trackingCode,
                        serviceLabel: _serviceLabel(order.serviceType),
                      ),
                      const _LabelDivider(),
                      _LabelBlock(
                        label: OrderPrintLabelStrings.recipient,
                        value: _fallback(order.recipientName),
                        valueStyle: AppTextStyles.headingMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                        trailing: _fallback(order.recipientPhone),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _LabelBlock(
                        label: OrderPrintLabelStrings.deliveryAddress,
                        value: _fallback(order.deliveryAddress),
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _LabelBlock(
                        label: OrderPrintLabelStrings.pickupAddress,
                        value: _fallback(order.pickupAddress),
                        maxLines: 2,
                        compact: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CollectionBand(amount: collectionAmount),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _LabelBlock(
                                label: OrderPrintLabelStrings.cargo,
                                value: cargoNameOrFallback(order),
                                maxLines: 2,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _LabelBlock(
                                label: OrderPrintLabelStrings.note,
                                value: _fallback(order.note),
                                maxLines: 3,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const _LabelDivider(),
                      SizedBox(
                        key: orderShippingLabelBarcodeKey,
                        width: double.infinity,
                        height: 46,
                        child: CustomPaint(
                          painter: _DemoBarcodePainter(seed: trackingCode),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: Text(
                          trackingCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.mono.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelHeader extends StatelessWidget {
  const _LabelHeader({required this.trackingCode, required this.serviceLabel});

  final String trackingCode;
  final String serviceLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                OrderPrintLabelStrings.brand,
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                trackingCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mono.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.textPrimary, width: 1.5),
            borderRadius: AppRadius.xs,
          ),
          child: Text(
            serviceLabel,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _CollectionBand extends StatelessWidget {
  const _CollectionBand({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final label = amount > 0
        ? '${OrderPrintLabelStrings.collectOnDelivery}: ${_formatMoney(amount)}'
        : OrderPrintLabelStrings.noCollection;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.textPrimary,
      child: Row(
        children: [
          const Icon(
            Icons.payments_outlined,
            color: AppColors.bgCard,
            size: 19,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.bgCard,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelBlock extends StatelessWidget {
  const _LabelBlock({
    required this.label,
    required this.value,
    this.trailing,
    this.maxLines = 2,
    this.compact = false,
    this.valueStyle,
  });

  final String label;
  final String value;
  final String? trailing;
  final int maxLines;
  final bool compact;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style:
              valueStyle ??
              AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
        ),
        if (trailing != null) ...[
          const SizedBox(height: 2),
          Text(
            trailing!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.mono.copyWith(
              color: AppColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _LabelDivider extends StatelessWidget {
  const _LabelDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      color: AppColors.textPrimary,
    );
  }
}

class _DemoBarcodePainter extends CustomPainter {
  const _DemoBarcodePainter({required this.seed});

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.textPrimary;
    var state = seed.codeUnits.fold<int>(
      17,
      (value, unit) => value * 31 + unit,
    );
    var x = 0.0;
    while (x < size.width) {
      state = (state * 1103515245 + 12345) & 0x7fffffff;
      final barWidth = 1.0 + (state % 3);
      final gap = 1.0 + ((state >> 4) % 2);
      canvas.drawRect(Rect.fromLTWH(x, 0, barWidth, size.height), paint);
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DemoBarcodePainter oldDelegate) =>
      oldDelegate.seed != seed;
}

String _fallback(String? value, {String? fallback}) {
  final text = value?.trim();
  return text == null || text.isEmpty
      ? (fallback ?? OrderPrintLabelStrings.noData)
      : text;
}

String _serviceLabel(String value) {
  return switch (value) {
    'express' => OrderPrintLabelStrings.expressService,
    'fragile' => OrderPrintLabelStrings.fragileService,
    'document' => OrderPrintLabelStrings.documentService,
    _ => OrderPrintLabelStrings.standardService,
  };
}

String _formatMoney(int amount) {
  final value = amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  return '$value\u0111';
}
