import 'package:flutter/material.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: _AppSpacing.lg),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: _AppColors.accentLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _AppColors.accent,
                  size: 30,
                ),
              ),
              const SizedBox(width: _AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nguyễn Khách Hàng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: _AppSpacing.xs),
                    Text(
                      'customer@datn.vn',
                      style: TextStyle(
                        fontSize: 13,
                        color: _AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: _AppSpacing.xl),
          const _ProfileMenuTile(
            icon: Icons.history_rounded,
            title: 'Lịch sử giao hàng',
            subtitle: 'Xem lại các đơn hàng đã hoàn thành',
          ),
          const SizedBox(height: _AppSpacing.md),
          const _ProfileMenuTile(
            icon: Icons.location_on_outlined,
            title: 'Địa chỉ đã lưu',
            subtitle: 'Quản lý điểm lấy hàng và giao hàng',
          ),
          const SizedBox(height: _AppSpacing.md),
          const _ProfileMenuTile(
            icon: Icons.support_agent_rounded,
            title: 'Hỗ trợ khách hàng',
            subtitle: 'Liên hệ khi cần trợ giúp về đơn hàng',
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_AppSpacing.lg),
      decoration: BoxDecoration(
        color: _AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _AppShadow.card,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _AppColors.accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _AppColors.accent, size: 22),
          ),
          const SizedBox(width: _AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: _AppSpacing.xs),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: _AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: _AppSpacing.sm),
          const Icon(
            Icons.chevron_right_rounded,
            color: _AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _AppColors {
  static const accent = Color(0xFFFF6B35);
  static const accentLight = Color(0xFFFFEDE6);
  static const bgCard = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);
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