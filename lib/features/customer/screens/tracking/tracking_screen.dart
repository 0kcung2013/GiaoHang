import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/models/order_status_log_model.dart';
import '../../../../core/providers/customer_providers.dart';

part 'tracking_widgets.dart';
part 'tracking_helpers.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final _searchController = TextEditingController();
  String? _trackingCode;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final value = _searchController.text.trim();
    if (value.isEmpty) {
      setState(() => _trackingCode = null);
      return;
    }
    setState(() => _trackingCode = value);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _TrackingLayout.fromWidth(constraints.maxWidth);
        final trackingCode = _trackingCode;

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
                  const _TrackingHeader(),
                  SizedBox(height: layout.headerGap),
                  _SearchCard(
                    controller: _searchController,
                    onSearch: _submitSearch,
                  ),
                  SizedBox(height: layout.sectionGap),
                  if (trackingCode == null)
                    const _TrackingMessageCard(
                      icon: Icons.search_rounded,
                      title: 'Nhập mã đơn hàng',
                      message:
                          'Tra cứu bằng mã vận đơn để xem trạng thái giao hàng hiện tại.',
                    )
                  else
                    _TrackingLookupResult(trackingCode: trackingCode),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackingLookupResult extends ConsumerWidget {
  final String trackingCode;

  const _TrackingLookupResult({required this.trackingCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOrder = ref.watch(orderByTrackingCodeProvider(trackingCode));

    return asyncOrder.when(
      loading: () => const _TrackingMessageCard(
        icon: Icons.hourglass_top_rounded,
        title: 'Đang tải đơn hàng',
        message: 'Vui lòng chờ trong giây lát.',
        showLoader: true,
      ),
      error: (_, _) => _TrackingMessageCard(
        icon: Icons.error_outline_rounded,
        title: 'Không tải được đơn hàng',
        message: 'Vui lòng kiểm tra kết nối và thử lại.',
        color: AppColors.error,
        actionLabel: 'Thử lại',
        onAction: () =>
            ref.invalidate(orderByTrackingCodeProvider(trackingCode)),
      ),
      data: (order) {
        if (order == null) {
          return const _TrackingMessageCard(
            icon: Icons.inventory_2_outlined,
            title: 'Không tìm thấy đơn hàng',
            message: 'Mã đơn hàng không tồn tại hoặc bạn không có quyền xem.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _StateActionButton(
                label: 'Làm mới',
                onTap: () {
                  ref.invalidate(orderByTrackingCodeProvider(trackingCode));
                  ref.invalidate(orderStatusLogsProvider(order.id));
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _TrackingTimeline(order: order),
            const SizedBox(height: AppSpacing.xl2 + AppSpacing.xs),
            _PackageInfoCard(order: order),
          ],
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
