import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';

// ── TrackingScreen ───────────────────────────────────────────────────────────
//
// Điểm đáng chú ý:
//  • Search bar bo góc 12px, viền borderLight, icon kính lúp bên trái.
//  • Timeline dọc sử dụng Column + Row kết hợp:
//    - Dot tròn 14px: filled accent nếu đã qua, outline textMuted nếu chưa.
//    - Line dọc nối giữa các dot, accent nếu đã qua, borderLight nếu chưa.
//    - Mỗi bước: tên trạng thái (w600) + thời gian (accent) + mô tả (textMuted).
//  • Thông tin gói hàng hiển thị trong card trắng bo góc 16px, viền borderLight.

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _searchController = TextEditingController();

  static const List<_TimelineStep> _steps = [
    _TimelineStep(
      title: 'Đơn hàng đã đặt',
      time: '14:30 · 28/05/2024',
      description: 'Khách hàng đã đặt đơn thành công',
      done: true,
    ),
    _TimelineStep(
      title: 'Đã xác nhận',
      time: '14:35 · 28/05/2024',
      description: 'Shop đã xác nhận và đang chuẩn bị hàng',
      done: true,
    ),
    _TimelineStep(
      title: 'Đã lấy hàng',
      time: '15:00 · 28/05/2024',
      description: 'Tài xế đã đến lấy hàng tại điểm gửi',
      done: true,
    ),
    _TimelineStep(
      title: 'Đang giao hàng',
      time: '15:20 · 28/05/2024',
      description: 'Đơn hàng đang trên đường giao đến bạn',
      done: true,
    ),
    _TimelineStep(
      title: 'Giao hàng thành công',
      time: 'Chưa cập nhật',
      description: 'Đơn hàng sẽ được giao đến địa chỉ của bạn',
      done: false,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Theo dõi đơn',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: NavColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),

          // Search bar
          Container(
            decoration: BoxDecoration(
              color: NavColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NavColors.borderLight, width: 1),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 15,
                color: NavColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Nhập mã đơn hàng...',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: NavColors.textMuted,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: NavColors.textMuted,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Timeline
          const _TrackingTimeline(steps: _steps),
          const SizedBox(height: 24),

          // Package Info Card
          const _PackageInfoCard(),
        ],
      ),
    );
  }
}

// ── Timeline Step Data ───────────────────────────────────────────────────────
class _TimelineStep {
  final String title;
  final String time;
  final String description;
  final bool done;

  const _TimelineStep({
    required this.title,
    required this.time,
    required this.description,
    required this.done,
  });
}

// ── Tracking Timeline ────────────────────────────────────────────────────────
class _TrackingTimeline extends StatelessWidget {
  final List<_TimelineStep> steps;

  const _TrackingTimeline({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isLast = i == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cột dot + line
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    // Dot — filled nếu đã qua, outline nếu chưa
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        color: step.done ? NavColors.accent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: step.done ? NavColors.accent : NavColors.textMuted,
                          width: 2,
                        ),
                      ),
                      child: step.done
                          ? const Icon(Icons.check, color: Colors.white, size: 8)
                          : null,
                    ),

                    // Line nối dọc — chỉ hiển thị nếu không phải bước cuối
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: step.done
                              ? NavColors.accent
                              : NavColors.borderLight,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Nội dung bước
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: step.done
                              ? NavColors.textPrimary
                              : NavColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.time,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: step.done
                              ? NavColors.accent
                              : NavColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: NavColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Package Info Card ────────────────────────────────────────────────────────
class _PackageInfoCard extends StatelessWidget {
  const _PackageInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NavColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NavColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin gói hàng',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: NavColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: NavColors.borderLight, height: 1),
          const SizedBox(height: 12),
          _infoRow('Mã đơn', '#DH-20241'),
          _infoRow('Người nhận', 'Nguyễn Văn An'),
          _infoRow('Điện thoại', '0912 345 678'),
          _infoRow('Địa chỉ giao', '123 Lê Lợi, Q.1, TP.HCM'),
          _infoRow('Khối lượng', '1.5 kg', isLast: true),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: NavColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: NavColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}