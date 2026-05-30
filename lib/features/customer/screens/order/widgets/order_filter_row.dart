import 'package:flutter/material.dart';
import 'order_theme.dart';

class OrderFilterRow extends StatelessWidget {
  const OrderFilterRow({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: const Row(
        children: [
          _FilterChip(label: 'Tất cả', isSelected: true),
          SizedBox(width: OrderSpacing.sm),
          _FilterChip(label: 'Đang giao', isSelected: false),
          SizedBox(width: OrderSpacing.sm),
          _FilterChip(label: 'Hoàn thành', isSelected: false),
          SizedBox(width: OrderSpacing.sm),
          _FilterChip(label: 'Đã hủy', isSelected: false),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OrderSpacing.lg,
        vertical: OrderSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isSelected ? OrderColors.primary : Colors.white,
        border: Border.all(
          color: isSelected ? Colors.transparent : OrderColors.border,
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: isSelected ? OrderShadow.subtle : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : OrderColors.textSecondary,
        ),
      ),
    );
  }
}