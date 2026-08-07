import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/models/order_status_log_model.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/services/osrm_service.dart';
import '../../../../core/utils/delivery_map_utils.dart';
import '../../../../core/utils/delivery_traffic_route_analyzer.dart';
import '../../../../core/utils/text_encoding_utils.dart';
import '../../../../core/widgets/delivery_map_markers.dart';
import '../../../../core/widgets/delivery_traffic_map_layer.dart';
import '../../../../core/widgets/order_cargo_info_block.dart';
import '../../../reviews/widgets/order_review_section.dart';
import '../../widgets/delivery_proof/customer_delivery_proof_section.dart';
import '../../widgets/order_assignment_status_card.dart';
import '../order/order_helpers.dart';
import 'utils/tracking_driver_position.dart';
import 'utils/tracking_location_motion.dart';
import 'utils/tracking_map_phase.dart';
import 'widgets/assigned_driver_card.dart';

part 'tracking_widgets.dart';
part 'tracking_helpers.dart';
part 'widgets/tracking_map.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, this.initialTrackingCode});

  /// Mã đơn prefill (từ màn đặt thành công / deep link).
  final String? initialTrackingCode;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final _searchController = TextEditingController();
  String? _trackingCode;

  @override
  void initState() {
    super.initState();
    _applyInitialTrackingCode();
  }

  @override
  void didUpdateWidget(covariant TrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTrackingCode != oldWidget.initialTrackingCode) {
      _applyInitialTrackingCode();
    }
  }

  void _applyInitialTrackingCode() {
    final initial = widget.initialTrackingCode?.trim() ?? '';
    _searchController.text = initial;
    _trackingCode = initial.isEmpty ? null : initial;
  }

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
    final currentOrder = asyncOrder.valueOrNull;

    if (currentOrder != null) {
      return _buildTrackedOrder(
        ref: ref,
        order: currentOrder,
        isRefreshing: asyncOrder.isRefreshing || asyncOrder.isReloading,
      );
    }

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

        return _buildTrackedOrder(ref: ref, order: order, isRefreshing: false);
      },
    );
  }

  Widget _buildTrackedOrder({
    required WidgetRef ref,
    required OrderModel order,
    required bool isRefreshing,
  }) {
    debugPrint(
      '[TrackingRealtime] tracking screen watching subscription '
      'orderId=${order.id} trackingCode=$trackingCode',
    );
    ref.watch(
      trackedOrderRealtimeProvider((
        orderId: order.id,
        trackingCode: trackingCode,
      )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isRefreshing) ...[
              const _InlineLoading(label: 'Đang cập nhật...'),
              const SizedBox(width: AppSpacing.md),
            ],
            _StateActionButton(
              label: 'Làm mới',
              onTap: () {
                ref.invalidate(orderByTrackingCodeProvider(trackingCode));
                ref.invalidate(orderStatusLogsProvider(order.id));
                ref.invalidate(assignedDriverProvider(order.id));
                ref.invalidate(orderDeliveryProofsProvider(order.id));
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (order.canWaitForDriver) ...[
          OrderAssignmentStatusCard(order: order),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_shouldShowOrderMap(order)) ...[
          _TrackingMap(order: order),
          const SizedBox(height: AppSpacing.md),
        ],
        _TrackingTimeline(order: order),
        if (const {
          'picking_up',
          'delivering',
          'delivered',
        }.contains(order.status)) ...[
          const SizedBox(height: AppSpacing.md),
          CustomerDeliveryProofSection(
            orderId: order.id,
            orderStatus: order.status,
          ),
        ],
        if (shouldShowAssignedDriverForOrder(order)) ...[
          const SizedBox(height: AppSpacing.xl2 + AppSpacing.xs),
          AssignedDriverCard(orderId: order.id),
        ],
        if (order.status == 'delivered') ...[
          const SizedBox(height: AppSpacing.md),
          OrderReviewSection(order: order),
        ],
        const SizedBox(height: AppSpacing.xl2 + AppSpacing.xs),
        _PackageInfoCard(order: order),
      ],
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
