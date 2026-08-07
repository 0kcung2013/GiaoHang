import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../core/location/driver_foreground_location_service.dart';
import '../../../core/providers/customer_providers.dart';
import '../../notifications/models/notification_inbox_item.dart';
import '../../notifications/widgets/notification_bell_button.dart';
import 'account/driver_account_screen.dart';
import 'earnings/driver_earnings_screen.dart';
import 'home/home_screen.dart';
import 'home/utils/driver_home_formatters.dart';
import 'orders/driver_orders_screen.dart';
import 'widgets/driver_drawer.dart';
import 'widgets/driver_active_delivery_location_tracker.dart';
import 'widgets/driver_gps_debug_dialog.dart';

class DriverShellScreen extends ConsumerStatefulWidget {
  const DriverShellScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<DriverShellScreen> createState() => _DriverShellScreenState();
}

class _DriverShellScreenState extends ConsumerState<DriverShellScreen> {
  static const _tabs = [
    DriverHomeScreen(),
    DriverOrdersScreen(),
    DriverEarningsScreen(),
    DriverAccountScreen(),
  ];

  static const _titles = ['Tổng quan', 'Đơn hàng', 'Thu nhập', 'Tài khoản'];

  late int _currentIndex;
  String? _lastHandledCancellationEventId;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.clamp(0, _tabs.length - 1);
  }

  @override
  void didUpdateWidget(covariant DriverShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _currentIndex = widget.initialTab.clamp(0, _tabs.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser != null) {
      ref.watch(driverCancelledOrderRealtimeProvider(currentUser.id));
      ref.listen(driverOrdersProvider(currentUser.id), (previous, next) {
        final hasActiveOrder =
            next.valueOrNull?.any(isActiveDriverOrder) ?? true;
        if (!hasActiveOrder) {
          unawaited(DriverForegroundLocationService.stop());
        }
      });
      ref.listen(driverOrderCancellationEventProvider, (previous, next) {
        if (next == null || next.eventId == _lastHandledCancellationEventId) {
          return;
        }
        _lastHandledCancellationEventId = next.eventId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showCancelledDialog(next.orderId, next.orderCode, currentUser.id);
          }
        });
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFFAF6),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        titleSpacing: AppSpacing.sm,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _titles[_currentIndex],
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.accent),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Kiểm tra vị trí',
              onPressed: _showGpsDebugSheet,
              icon: const Icon(Icons.my_location_rounded),
            ),
          const NotificationBellButton(audience: NotificationAudience.driver),
          const SizedBox(width: AppSpacing.sm),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: ColoredBox(
            color: AppColors.accentLight,
            child: const SizedBox(height: 1),
          ),
        ),
      ),
      drawer: DriverDrawer(
        currentIndex: _currentIndex,
        onNavigate: (index) => setState(() => _currentIndex = index),
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: _tabs),
            if (currentUser != null)
              DriverActiveDeliveryLocationTracker(
                userId: currentUser.id,
                email: currentUser.email,
              ),
          ],
        ),
      ),
    );
  }

  void _showGpsDebugSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DriverGpsDebugSheet(),
    );
  }

  void _showCancelledDialog(
    String orderId,
    String orderCode,
    String currentUserId,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.xl2),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.xl2,
            boxShadow: AppShadow.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: AppColors.error,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Khách hàng đã huỷ đơn',
                textAlign: TextAlign.center,
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Đơn $orderCode đã bị huỷ. '
                'Bạn có thể tiếp tục nhận đơn khác.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl2),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textOnAccent,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
                  ),
                  child: Text(
                    'Đã hiểu',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textOnAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      ref.invalidate(availableOrdersProvider(currentUserId));
      ref.invalidate(driverOrdersProvider(currentUserId));
    });
  }
}
