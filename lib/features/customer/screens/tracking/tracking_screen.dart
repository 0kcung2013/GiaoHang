import 'package:flutter/material.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: _AppSpacing.lg),
          const Text(
            'Theo dõi',
            style: TextStyle(
              fontSize: 22,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: _AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: _AppSpacing.xs),
          const Text(
            'Tab này sẽ hiển thị bản đồ và vị trí tài xế theo thời gian thực.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: _AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: _AppSpacing.xl),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(_AppSpacing.xl),
              decoration: BoxDecoration(
                color: _AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _AppShadow.card,
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 48,
                    color: _AppColors.info,
                  ),
                  SizedBox(height: _AppSpacing.md),
                  Text(
                    'Bản đồ tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: _AppSpacing.sm),
                  Text(
                    'Sẵn sàng để kết nối với màn hình theo dõi đơn hàng ở bước tiếp theo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: _AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppColors {
  static const info = Color(0xFF3B82F6);
  static const bgCard = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
}

class _AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const screenH = 20.0;
}

class _AppShadow {
  static const card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
}