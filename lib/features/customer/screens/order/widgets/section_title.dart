import 'package:flutter/material.dart';

import 'order_theme.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  const SectionTitle({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: OrderColors.textPrimary,
            ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: OrderColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}