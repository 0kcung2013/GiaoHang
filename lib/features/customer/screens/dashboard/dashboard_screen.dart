import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _AppSpacing.screenH,
              _AppSpacing.lg,
              _AppSpacing.screenH,
              _AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderSection(),
                const SizedBox(height: _AppSpacing.lg),
                const _SearchBar(),
                const SizedBox(height: _AppSpacing.lg),
                const _QuickActions(),
                const SizedBox(height: _AppSpacing.xl),
                _SectionTitle(
                  title: 'Đơn hàng gần đây',
                  actionLabel: 'Xem tất cả',
                  onTap: () {},
                ),
                const SizedBox(height: _AppSpacing.md),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: _AppSpacing.screenH),
          sliver: SliverList.separated(
            itemCount: _recentOrders.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: _AppSpacing.md),
            itemBuilder: (context, index) {
              final order = _recentOrders[index];
              return _OrderCard(
                order: order,
                actionLabel: 'Theo dõi',
                onTap: () {},
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _AppSpacing.screenH,
              _AppSpacing.xl2,
              _AppSpacing.screenH,
              _AppSpacing.xl3,
            ),
            child: _PrimaryButton(
              label: 'Đặt hàng mới',
              icon: Icons.add_location_alt_rounded,
              onTap: () {},
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xin chào, Khách hàng',
                style: TextStyle(
                  fontSize: 22,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: _AppColors.textPrimary,
                ),
              ),
              SizedBox(height: _AppSpacing.xs),
              Text(
                'Bạn muốn giao gì hôm nay?',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  color: _AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: _AppColors.bgCard,
            shape: BoxShape.circle,
            boxShadow: _AppShadow.subtle,
          ),
          child: IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: _AppColors.primary,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: _AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _AppShadow.card,
      ),
      child: const Row(
        children: [
          SizedBox(width: _AppSpacing.lg),
          Icon(Icons.search_rounded, color: _AppColors.textMuted, size: 22),
          SizedBox(width: _AppSpacing.sm),
          Expanded(
            child: Text(
              'Tìm địa chỉ giao hàng...',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: _AppColors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: _AppSpacing.sm),
          Icon(Icons.tune_rounded, color: _AppColors.primary, size: 20),
          SizedBox(width: _AppSpacing.lg),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: _AppSpacing.sm,
      runSpacing: _AppSpacing.sm,
      children: [
        _QuickChip(
          icon: Icons.local_shipping_rounded,
          label: 'Giao nhanh',
        ),
        _QuickChip(
          icon: Icons.inventory_2_rounded,
          label: 'Hàng cồng kềnh',
        ),
        _QuickChip(
          icon: Icons.history_rounded,
          label: 'Đặt lại đơn cũ',
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _AppSpacing.md,
        vertical: _AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: _AppColors.accentLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _AppColors.accent),
          const SizedBox(width: _AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  const _SectionTitle({
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
              color: _AppColors.textPrimary,
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
              color: _AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            color: _AppColors.accent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: _AppShadow.accentGlow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _AppColors.textOnAccent, size: 20),
              const SizedBox(width: _AppSpacing.sm),
              const Text(
                'Đặt hàng mới',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _AppColors.textOnAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final _OrderVm order;
  final String actionLabel;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = _statusColor(order.status);

    return Container(
      padding: const EdgeInsets.all(_AppSpacing.lg),
      decoration: BoxDecoration(
        color: _AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderCode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _AppColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: _AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _AppSpacing.md),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: _AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _AppColors.accentLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.packageType,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: _AppSpacing.sm),
              Expanded(
                child: Text(
                  order.priceText,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                children: [
                  Icon(
                    Icons.radio_button_checked_rounded,
                    size: 14,
                    color: _AppColors.markerPickup,
                  ),
                  SizedBox(
                    height: 30,
                    child: VerticalDivider(
                      width: 20,
                      thickness: 1.2,
                      color: _AppColors.border,
                    ),
                  ),
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: _AppColors.markerDrop,
                  ),
                ],
              ),
              const SizedBox(width: _AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.pickupAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: _AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: _AppSpacing.md),
                    Text(
                      order.deliveryAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: _AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: _AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: _AppColors.textMuted,
              ),
              const SizedBox(width: _AppSpacing.xs),
              Expanded(
                child: Text(
                  order.timeText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  foregroundColor: _AppColors.primary,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: _AppSpacing.sm),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Đang lấy hàng':
        return _AppColors.accent;
      case 'Đang giao':
        return _AppColors.info;
      case 'Hoàn thành':
        return _AppColors.success;
      case 'Đã hủy':
        return _AppColors.error;
      default:
        return _AppColors.warning;
    }
  }
}

class _OrderVm {
  final String orderCode;
  final String status;
  final String pickupAddress;
  final String deliveryAddress;
  final String timeText;
  final String packageType;
  final String priceText;

  const _OrderVm({
    required this.orderCode,
    required this.status,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.timeText,
    required this.packageType,
    required this.priceText,
  });
}

const _recentOrders = [
  _OrderVm(
    orderCode: '#GH-29041',
    status: 'Đang lấy hàng',
    pickupAddress: '12 Nguyễn Huệ, Quận 1, TP. HCM',
    deliveryAddress: '89 Cộng Hòa, Tân Bình, TP. HCM',
    timeText: 'Cập nhật 2 phút trước',
    packageType: 'Hỏa tốc',
    priceText: '45.000đ',
  ),
  _OrderVm(
    orderCode: '#GH-29039',
    status: 'Đang giao',
    pickupAddress: '21 Lê Lợi, Quận 1, TP. HCM',
    deliveryAddress: '37 Trường Chinh, Tân Phú, TP. HCM',
    timeText: 'Cập nhật 7 phút trước',
    packageType: 'Tiêu chuẩn',
    priceText: '32.000đ',
  ),
  _OrderVm(
    orderCode: '#GH-29010',
    status: 'Hoàn thành',
    pickupAddress: '145 Điện Biên Phủ, Bình Thạnh, TP. HCM',
    deliveryAddress: '9 Hoàng Văn Thụ, Phú Nhuận, TP. HCM',
    timeText: 'Hôm nay, 08:12',
    packageType: 'Tài liệu',
    priceText: '25.000đ',
  ),
];

class _AppColors {
  static const primary = Color(0xFF0F1B2D);
  static const accent = Color(0xFFFF6B35);
  static const accentLight = Color(0xFFFFEDE6);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
  static const bgCard = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);
  static const textOnAccent = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const markerPickup = Color(0xFF3B82F6);
  static const markerDrop = Color(0xFFFF6B35);
}

class _AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xl2 = 24.0;
  static const xl3 = 32.0;
  static const screenH = 20.0;
}

class _AppShadow {
  static const subtle = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const accentGlow = [
    BoxShadow(color: Color(0x40FF6B35), blurRadius: 20, offset: Offset(0, 6)),
  ];
}