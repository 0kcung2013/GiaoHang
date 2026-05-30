import 'package:flutter/material.dart';
import 'order_theme.dart';

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OrderSpacing.lg),
      decoration: BoxDecoration(
        color: OrderColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: OrderShadow.card,
      ),
      child: const Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: 'Đang giao',
              value: '03',
              valueColor: OrderColors.textOnDark,
            ),
          ),
          _SummaryDivider(),
          Expanded(
            child: _SummaryItem(
              label: 'Hoàn thành',
              value: '18',
              valueColor: OrderColors.textOnDark,
            ),
          ),
          _SummaryDivider(),
          Expanded(
            child: _SummaryItem(
              label: 'Đã hủy',
              value: '01',
              valueColor: OrderColors.textOnDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        const SizedBox(height: OrderSpacing.xs),
        const Text(
          '',
          style: TextStyle(fontSize: 0),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: OrderColors.textOnDarkMuted,
          ),
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      color: Colors.white.withValues(alpha: 0.14),
    );
  }
}