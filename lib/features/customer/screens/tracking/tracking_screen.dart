import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _TrackingLayout.fromWidth(constraints.maxWidth);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            layout.horizontalPadding,
            layout.topPadding,
            layout.horizontalPadding,
            AppSpacing.xl2,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const _TrackingHeader(),
                  SizedBox(height: layout.headerGap),

                  // Search bar
                  _SearchCard(controller: _searchController),
                  SizedBox(height: layout.sectionGap),

                  // Timeline
                  const _TrackingTimeline(steps: _steps),
                  SizedBox(height: layout.sectionGap),

                  // Package Info Card
                  const _PackageInfoCard(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackingLayout {
  static const tabletBreakpoint = 600.0;
  static const desktopBreakpoint = 1024.0;
  static const tabletContentMaxWidth = 720.0;
  static const desktopContentMaxWidth = 760.0;

  final double horizontalPadding;
  final double topPadding;
  final double headerGap;
  final double sectionGap;
  final double maxContentWidth;

  const _TrackingLayout({
    required this.horizontalPadding,
    required this.topPadding,
    required this.headerGap,
    required this.sectionGap,
    required this.maxContentWidth,
  });

  factory _TrackingLayout.fromWidth(double width) {
    if (width > desktopBreakpoint) {
      return const _TrackingLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        headerGap: AppSpacing.xl,
        sectionGap: AppSpacing.xl3,
        maxContentWidth: desktopContentMaxWidth,
      );
    }

    if (width >= tabletBreakpoint) {
      return const _TrackingLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        headerGap: AppSpacing.xl,
        sectionGap: AppSpacing.xl2,
        maxContentWidth: tabletContentMaxWidth,
      );
    }

    return const _TrackingLayout(
      horizontalPadding: AppSpacing.screenH,
      topPadding: AppSpacing.xl2,
      headerGap: AppSpacing.lg,
      sectionGap: AppSpacing.xl2 + AppSpacing.xs,
      maxContentWidth: double.infinity,
    );
  }
}

class _TrackingHeader extends StatelessWidget {
  const _TrackingHeader();

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
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.route_rounded,
              color: AppColors.textOnDark,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theo dõi đơn',
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Kiểm tra trạng thái giao hàng hiện tại',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController controller;

  const _SearchCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadow.card,
      ),
      child: TextField(
        controller: controller,
        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Nhập mã đơn hàng...',
          hintStyle: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textMuted,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tiến trình giao hàng',
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Column(
            children: List.generate(steps.length, (i) {
              final step = steps[i];
              final isLast = i == steps.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cột dot + line
                    SizedBox(
                      width: AppSpacing.xl2,
                      child: Column(
                        children: [
                          // Dot — filled nếu đã qua, outline nếu chưa
                          Container(
                            width: AppSpacing.lg,
                            height: AppSpacing.lg,
                            margin: const EdgeInsets.only(top: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: step.done
                                  ? AppColors.accent
                                  : AppColors.bgCard,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: step.done
                                    ? AppColors.accent
                                    : AppColors.border,
                                width: 2,
                              ),
                              boxShadow: step.done ? AppShadow.subtle : null,
                            ),
                            child: step.done
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.textOnAccent,
                                    size: AppSpacing.sm,
                                  )
                                : null,
                          ),

                          // Line nối dọc — chỉ hiển thị nếu không phải bước cuối
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xs,
                                ),
                                color: step.done
                                    ? AppColors.accent.withValues(alpha: 0.45)
                                    : AppColors.border,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Nội dung bước
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: isLast ? 0 : AppSpacing.xl2,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: step.done
                                ? AppColors.accentLight.withValues(alpha: 0.42)
                                : AppColors.bgLight,
                            borderRadius: AppRadius.lg,
                            border: Border.all(
                              color: step.done
                                  ? AppColors.accent.withValues(alpha: 0.14)
                                  : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: step.done
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                step.time,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: step.done
                                      ? AppColors.accent
                                      : AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                step.description,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Package Info Card ────────────────────────────────────────────────────────
class _PackageInfoCard extends StatelessWidget {
  const _PackageInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Thông tin gói hàng',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.md),
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
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
