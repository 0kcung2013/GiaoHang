import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class AddressMapDot extends StatelessWidget {
  const AddressMapDot({super.key, required this.color, required this.label});
  static const diameter = 14.0;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Tooltip(
      message: label,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.bgCard, width: 2),
          boxShadow: AppShadow.subtle,
        ),
      ),
    ),
  );
}
