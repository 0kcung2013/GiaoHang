import 'package:flutter/material.dart';

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

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
                const Text(
                  'Đơn hàng',
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: _AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: _AppSpacing.xs),
                const Text(
                  'Theo dõi trạng thái và quản lý tất cả đơn giao của bạn.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                    color: _AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: _AppSpacing.lg),
                const _OrdersSummaryCard(),
                const SizedBox(height: _AppSpacing.lg),
                const _OrderFilterRow(),
                const SizedBox(height: _AppSpacing.xl),
                _SectionTitle(
                  title: 'Tất cả đơn hàng',
                  actionLabel: 'Làm mới',
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
            itemCount: _allOrders.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: _AppSpacing.md),
            itemBuilder: (context, index) {
              final order = _allOrders[index];
              return _OrderCard(
                order: order,
                actionLabel:
                    order.status == 'Hoàn thành' ? 'Đặt lại' : 'Chi tiết',
                onTap: () {},
              );
            },
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: _AppSpacing.xl3),
        ),
      ],
    );
  }
}

class _OrdersSummaryCard extends StatelessWidget {
  const _OrdersSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_AppSpacing.lg),
      decoration: BoxDecoration(
        color: _AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _AppShadow.card,
      ),
      child: const Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: 'Đang giao',
              value: '03',
              valueColor: _AppColors.textOnDark,
            ),
          ),
          _SummaryDivider(),
          Expanded(
            child: _SummaryItem(
              label: 'Hoàn thành',
              value: '18',
              valueColor: _AppColors.textOnDark,
            ),
          ),
          _SummaryDivider(),
          Expanded(
            child: _SummaryItem(
              label: 'Đã hủy',
              value: '01',
              valueColor: _AppColors.textOnDark,
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
        const SizedBox(height: _AppSpacing.xs),
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
            color: _AppColors.textOnDarkMuted,
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

class _OrderFilterRow extends StatelessWidget {
  const _OrderFilterRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: _AppSpacing.sm,
      runSpacing: _AppSpacing.sm,
      children: [
        _FilterChip(label: 'Tất cả', selected: true),
        _FilterChip(label: 'Đang giao'),
        _FilterChip(label: 'Hoàn thành'),
        _FilterChip(label: 'Đã hủy'),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _FilterChip({
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _AppSpacing.md,
        vertical: _AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: selected ? _AppColors.primary : _AppColors.bgCard,
        borderRadius: BorderRadius.circular(999),
        border: selected ? null : Border.all(color: _AppColors.border),
        boxShadow: selected ? _AppShadow.subtle : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? _AppColors.textOnDark : _AppColors.textSecondary,
        ),
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

const _allOrders = [
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
    orderCode: '#GH-29022',
    status: 'Đã hủy',
    pickupAddress: '8 Pasteur, Quận 3, TP. HCM',
    deliveryAddress: '222 Lũy Bán Bích, Tân Phú, TP. HCM',
    timeText: 'Hôm qua, 18:40',
    packageType: 'Hàng dễ vỡ',
    priceText: '61.000đ',
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
  static const textOnDark = Color(0xFFF1F5F9);
  static const textOnDarkMuted = Color(0xFFCBD5E1);
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
}