import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';

// ── DashboardScreen ──────────────────────────────────────────────────────────
//
// Điểm đáng chú ý:
//  • Header có Greeting, Subtitle và Avatar tròn hiển thị chữ viết tắt của tên.
//  • Ô tóm tắt được xếp theo grid 2 cột sử dụng GridView với tỷ lệ thích hợp.
//  • Card tóm tắt bo góc 12px, viền màu nhạt, sử dụng phông số lớn w600 màu cam ấm.
//  • Khu vực đơn gần đây hiển thị danh sách dạng Card bo góc 12px, có badge trạng thái tròn màu đặc trưng.

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _DashboardLayout.fromWidth(constraints.maxWidth);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            layout.horizontalPadding,
            layout.topPadding,
            layout.horizontalPadding,
            AppSpacing.xl2,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _HeaderSection(name: 'Minh Tuấn', deliveringCount: 3),
                  SizedBox(height: layout.sectionGap),

                  // Summary Cards
                  const _SummaryGrid(),
                  SizedBox(height: layout.sectionGap),

                  // Đơn gần đây (List)
                  const _RecentOrdersSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardLayout {
  static const tabletBreakpoint = 600.0;
  static const desktopBreakpoint = 1024.0;
  static const tabletContentMaxWidth = 900.0;
  static const desktopContentMaxWidth = 1040.0;
  static const wideStatsMinWidth = 760.0;
  static const recentOrdersMaxWidth = 820.0;

  final double horizontalPadding;
  final double topPadding;
  final double sectionGap;
  final double maxContentWidth;

  const _DashboardLayout({
    required this.horizontalPadding,
    required this.topPadding,
    required this.sectionGap,
    required this.maxContentWidth,
  });

  factory _DashboardLayout.fromWidth(double width) {
    if (width > desktopBreakpoint) {
      return const _DashboardLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        sectionGap: AppSpacing.xl3,
        maxContentWidth: desktopContentMaxWidth,
      );
    }

    if (width >= tabletBreakpoint) {
      return const _DashboardLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        sectionGap: AppSpacing.xl2,
        maxContentWidth: tabletContentMaxWidth,
      );
    }

    return const _DashboardLayout(
      horizontalPadding: AppSpacing.screenH,
      topPadding: AppSpacing.xl2,
      sectionGap: AppSpacing.xl2,
      maxContentWidth: double.infinity,
    );
  }
}

// ── Header Section ───────────────────────────────────────────────────────────
class _HeaderSection extends StatelessWidget {
  final String name;
  final int deliveringCount;

  const _HeaderSection({required this.name, required this.deliveringCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.elevated,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, $name!',
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Bạn có $deliveringCount đơn đang giao',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: AppRadius.full,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    '$deliveringCount đơn cần theo dõi',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textOnDark,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Avatar tròn 40px chữ tắt tên
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.textOnDark.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textOnDark.withValues(alpha: 0.24),
              ),
            ),
            child: Center(
              child: Text(
                _getInitials(name),
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String fullName) {
    List<String> names = fullName.split(' ');
    if (names.length >= 2) {
      return '${names[names.length - 2][0]}${names[names.length - 1][0]}'
          .toUpperCase();
    }
    return fullName.isNotEmpty ? fullName.substring(0, 2).toUpperCase() : 'KH';
  }
}

// ── Summary Grid (2 cột) ──────────────────────────────────────────────────────
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth >= _DashboardLayout.wideStatsMinWidth ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: crossAxisCount == 4 ? 1.24 : 1.28,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _SummaryCard(
              value: '3',
              label: 'Đơn đang giao',
              icon: Icons.local_shipping_rounded,
              color: AppColors.accent,
            ),
            _SummaryCard(
              value: '12',
              label: 'Đã giao hôm nay',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
            ),
            _SummaryCard(
              value: '5',
              label: 'Chờ lấy hàng',
              icon: Icons.access_time_rounded,
              color: AppColors.warning,
            ),
            _SummaryCard(
              value: '20',
              label: 'Tổng hôm nay',
              icon: Icons.inventory_2_rounded,
              color: AppColors.info,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.displayMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Recent Orders Section ────────────────────────────────────────────────────
class _RecentOrdersSection extends StatelessWidget {
  const _RecentOrdersSection();

  @override
  Widget build(BuildContext context) {
    final List<_RecentOrderData> orders = [
      const _RecentOrderData(
        id: '#DH-20241',
        address: '123 Lê Lợi, Quận 1, TP. Hồ Chí Minh',
        status: 'Đang giao',
        statusColor: AppColors.accent,
      ),
      const _RecentOrderData(
        id: '#DH-20240',
        address: '45 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh',
        status: 'Hoàn thành',
        statusColor: AppColors.success,
      ),
      const _RecentOrderData(
        id: '#DH-20239',
        address: '789 Cách Mạng Tháng 8, Quận 3, TP. Hồ Chí Minh',
        status: 'Huỷ đơn',
        statusColor: AppColors.error,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth >= _DashboardLayout.wideStatsMinWidth
            ? _DashboardLayout.recentOrdersMaxWidth
            : double.infinity;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đơn gần đây',
                          style: AppTextStyles.headingSmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Cập nhật trạng thái mới nhất',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: AppRadius.full,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: AppRadius.full,
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              'Xem tất cả',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm + 2),
                  itemBuilder: (context, i) {
                    final order = orders[i];
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: AppRadius.lg,
                        border: Border.all(color: AppColors.border, width: 1),
                        boxShadow: AppShadow.card,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 48,
                            decoration: BoxDecoration(
                              color: order.statusColor,
                              borderRadius: AppRadius.full,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          // Icon tròn chỉ trạng thái
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: order.statusColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.local_shipping_outlined,
                              color: order.statusColor,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),

                          // Thông tin mã đơn + địa chỉ
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        order.id,
                                        style: AppTextStyles.labelMedium
                                            .copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    _StatusBadge(order: order),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  order.address,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _RecentOrderData order;

  const _StatusBadge({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: order.statusColor.withValues(alpha: 0.1),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        order.status,
        style: AppTextStyles.labelSmall.copyWith(
          color: order.statusColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _RecentOrderData {
  final String id;
  final String address;
  final String status;
  final Color statusColor;

  const _RecentOrderData({
    required this.id,
    required this.address,
    required this.status,
    required this.statusColor,
  });
}
