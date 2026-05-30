import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';

// ── OrderScreen ──────────────────────────────────────────────────────────────
//
// Điểm đáng chú ý:
//  • Chứa bộ lọc ngang nằm ngang (Tất cả / Đang giao / Hoàn thành / Huỷ).
//  • Khi nhấn chọn tab, màu nền và màu chữ sẽ chuyển đổi bằng hiệu ứng động nhẹ nhàng.
//  • Sử dụng thẻ đơn hàng bo góc 16px, viền mỏng và hiển thị đầy đủ thông tin:
//    mã đơn, người nhận, địa chỉ giao hàng, thời gian và badge trạng thái.
//  • Badge trạng thái sử dụng màu sematic đặc trưng (xanh / cam / đỏ / xám)
//    với độ mờ 8% để chữ có độ tương phản và dễ chịu nhất.

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  int _selectedFilterIndex = 0;

  static const List<String> _filters = ['Tất cả', 'Đang giao', 'Hoàn thành', 'Huỷ'];

  static const List<_OrderCardData> _allOrders = [
    _OrderCardData(
      id: '#DH-20241',
      recipient: 'Nguyễn Văn An',
      address: '123 Lê Lợi, Quận 1, TP. Hồ Chí Minh',
      time: '14:30 hôm nay',
      status: 'Đang giao',
      statusColor: NavColors.statusDelivering,
    ),
    _OrderCardData(
      id: '#DH-20240',
      recipient: 'Trần Thị Bích',
      address: '45 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh',
      time: '12:15 hôm nay',
      status: 'Hoàn thành',
      statusColor: NavColors.statusDone,
    ),
    _OrderCardData(
      id: '#DH-20239',
      recipient: 'Lê Minh Châu',
      address: '789 Cách Mạng Tháng 8, Quận 3, TP. Hồ Chí Minh',
      time: '10:00 hôm nay',
      status: 'Huỷ',
      statusColor: NavColors.statusCancelled,
    ),
    _OrderCardData(
      id: '#DH-20238',
      recipient: 'Phạm Quốc Duy',
      address: '56 Võ Văn Tần, Quận 3, TP. Hồ Chí Minh',
      time: 'Hôm qua 16:45',
      status: 'Hoàn thành',
      statusColor: NavColors.statusDone,
    ),
    _OrderCardData(
      id: '#DH-20237',
      recipient: 'Đỗ Thanh Tùng',
      address: '11 Đinh Tiên Hoàng, Bình Thạnh, TP. Hồ Chí Minh',
      time: 'Hôm qua 11:20',
      status: 'Đang giao',
      statusColor: NavColors.statusDelivering,
    ),
  ];

  List<_OrderCardData> get _filteredOrders {
    if (_selectedFilterIndex == 0) return _allOrders;
    final String activeStatusLabel = _filters[_selectedFilterIndex];
    return _allOrders.where((order) {
      if (activeStatusLabel == 'Huỷ') {
        return order.status == 'Huỷ';
      }
      return order.status == activeStatusLabel;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Screen
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Text(
            'Đơn hàng',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: NavColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),

        // Filter Tabs Ngang
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final active = _selectedFilterIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedFilterIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? NavColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(999), // pill / badge radius
                    border: active
                        ? null
                        : Border.all(color: NavColors.borderLight, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      _filters[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? Colors.white : NavColors.textMuted,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // List đơn hàng
        Expanded(
          child: _filteredOrders.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: _filteredOrders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    return _OrderCard(order: _filteredOrders[i]);
                  },
                ),
        ),
      ],
    );
  }
}

// ── Order Card ───────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final _OrderCardData order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NavColors.surface,
        borderRadius: BorderRadius.circular(16), // card radius 16px
        border: Border.all(color: NavColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mã đơn & Badge trạng thái
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.id,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: NavColors.textPrimary,
                ),
              ),
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
          const SizedBox(height: 12),

          // Tên người nhận
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 16, color: NavColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.recipient,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: NavColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Địa chỉ giao
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: NavColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.address,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NavColors.textMuted,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Thời gian
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: NavColors.textMuted),
              const SizedBox(width: 8),
              Text(
                order.time,
                style: const TextStyle(
                  fontSize: 12,
                  color: NavColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: NavColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            'Không tìm thấy đơn hàng nào',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: NavColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Order Card Data Class ─────────────────────────────────────────────────────
class _OrderCardData {
  final String id;
  final String recipient;
  final String address;
  final String time;
  final String status;
  final Color statusColor;

  const _OrderCardData({
    required this.id,
    required this.recipient,
    required this.address,
    required this.time,
    required this.status,
    required this.statusColor,
  });
}