import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';

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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _HeaderSection(
            name: 'Minh Tuấn',
            deliveringCount: 3,
          ),
          const SizedBox(height: 24),

          // Summary Cards (2 cột)
          const _SummaryGrid(),
          const SizedBox(height: 24),

          // Đơn gần đây (List)
          const _RecentOrdersSection(),
        ],
      ),
    );
  }
}

// ── Header Section ───────────────────────────────────────────────────────────
class _HeaderSection extends StatelessWidget {
  final String name;
  final int deliveringCount;

  const _HeaderSection({
    required this.name,
    required this.deliveringCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xin chào, $name!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: NavColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bạn có $deliveringCount đơn đang giao',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: NavColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        // Avatar tròn 40px chữ tắt tên
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: NavColors.accent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _getInitials(name),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getInitials(String fullName) {
    List<String> names = fullName.split(' ');
    if (names.length >= 2) {
      return '${names[names.length - 2][0]}${names[names.length - 1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName.substring(0, 2).toUpperCase() : 'KH';
  }
}

// ── Summary Grid (2 cột) ──────────────────────────────────────────────────────
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        _SummaryCard(value: '3', label: 'Đơn đang giao'),
        _SummaryCard(value: '12', label: 'Đã giao hôm nay'),
        _SummaryCard(value: '5', label: 'Chờ lấy hàng'),
        _SummaryCard(value: '20', label: 'Tổng hôm nay'),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryCard({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: NavColors.surface,
        borderRadius: BorderRadius.circular(12), // radius 12px
        border: Border.all(color: NavColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: NavColors.accent,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: NavColors.textMuted,
              height: 1.4,
            ),
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
        statusColor: NavColors.statusDelivering,
      ),
      const _RecentOrderData(
        id: '#DH-20240',
        address: '45 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh',
        status: 'Hoàn thành',
        statusColor: NavColors.statusDone,
      ),
      const _RecentOrderData(
        id: '#DH-20239',
        address: '789 Cách Mạng Tháng 8, Quận 3, TP. Hồ Chí Minh',
        status: 'Huỷ đơn',
        statusColor: NavColors.statusCancelled,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Đơn gần đây',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: NavColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Xem tất cả',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: NavColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final order = orders[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NavColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NavColors.borderLight, width: 1),
              ),
              child: Row(
                children: [
                  // Icon tròn chỉ trạng thái
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: order.statusColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_shipping_outlined,
                      color: order.statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Thông tin mã đơn + địa chỉ
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.id,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: NavColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.address,
                          style: const TextStyle(
                            fontSize: 12,
                            color: NavColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Badge trạng thái
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: order.statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: order.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
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