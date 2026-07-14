import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/providers/location_providers.dart';
import 'account/driver_account_screen.dart';
import 'earnings/driver_earnings_screen.dart';
import 'home/home_screen.dart';
import 'orders/driver_orders_screen.dart';
import 'widgets/driver_drawer.dart';

class DriverShellScreen extends ConsumerStatefulWidget {
  const DriverShellScreen({super.key});

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

  static const _titles = [
    'Tổng quan',
    'Đơn hàng',
    'Thu nhập',
    'Tài khoản',
  ];

  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final cancelledId = ref.watch(latestCancelledOrderIdProvider);
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser != null) {
      ref.watch(driverCancelledOrderRealtimeProvider(currentUser.id));
      ref.watch(driverOrdersRealtimeProvider(currentUser.id));

      if (cancelledId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(latestCancelledOrderIdProvider.notifier).state = null;
          if (mounted) _showCancelledDialog(cancelledId, currentUser.id);
        });
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _titles[_currentIndex],
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      drawer: DriverDrawer(
        currentIndex: _currentIndex,
        onNavigate: (index) => setState(() => _currentIndex = index),
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _currentIndex, children: _tabs),
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'debug_gps',
        backgroundColor: AppColors.accent,
        onPressed: () => _showGpsDebugDialog(),
        child: const Icon(Icons.gps_fixed_rounded, color: Colors.white),
      ),
    );
  }

  void _showGpsDebugDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _GpsDebugDialog(),
    );
  }

  void _showCancelledDialog(String orderId, String currentUserId) {
    final shortId =
        orderId.length >= 8 ? orderId.substring(0, 8) : orderId;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
        contentPadding: const EdgeInsets.all(AppSpacing.xl2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
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
            const SizedBox(height: AppSpacing.md),
            Text(
              'Đơn hàng đã bị huỷ',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Đơn #$shortId đã được khách hàng huỷ.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl2),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: AppColors.info,
                borderRadius: AppRadius.full,
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  borderRadius: AppRadius.full,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Center(
                      child: Text(
                        'Đã hiểu',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textOnAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      debugPrint('[DriverShellScreen] Cancelled dialog dismissed. Refreshing order list providers.');
      // ignore: unused_result
      ref.refresh(availableOrdersProvider(currentUserId));
      // ignore: unused_result
      ref.refresh(driverOrdersProvider(currentUserId));
    });
  }
}

class _GpsDebugDialog extends ConsumerStatefulWidget {
  const _GpsDebugDialog();

  @override
  ConsumerState<_GpsDebugDialog> createState() => _GpsDebugDialogState();
}

class _GpsDebugDialogState extends ConsumerState<_GpsDebugDialog> {
  String _status = 'Chưa test';
  double? _lat;
  double? _lng;
  int _updateCount = 0;
  bool _isTracking = false;

  @override
  void dispose() {
    ref.read(locationServiceProvider).stopTracking();
    super.dispose();
  }

  Future<void> _testPermission() async {
    setState(() => _status = 'Đang xin quyền...');
    final service = ref.read(locationServiceProvider);
    final ok = await service.requestPermission();
    setState(() => _status = ok ? 'Quyền GPS: OK' : 'Quyền GPS: BỊ TỪ CHỐI');
  }

  Future<void> _testGetPosition() async {
    setState(() => _status = 'Đang lấy vị trí...');
    final service = ref.read(locationServiceProvider);
    final pos = await service.getCurrentPosition();
    if (pos == null) {
      setState(() => _status = 'Lỗi: Không lấy được vị trí');
      return;
    }
    setState(() {
      _lat = pos.latitude;
      _lng = pos.longitude;
      _status = 'Vị trí OK: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
    });
  }

  void _testStartTracking() {
    if (_isTracking) return;
    setState(() {
      _isTracking = true;
      _status = 'Đang tracking...';
      _updateCount = 0;
    });

    final service = ref.read(locationServiceProvider);

    service.startTracking(
      onPosition: (pos) {
        setState(() {
          _updateCount++;
          _lat = pos.latitude;
          _lng = pos.longitude;
          _status = 'Tracking #$_updateCount: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
        });
        debugPrint('[GPS-TEST] $_status');
      },
      onError: (err) {
        setState(() => _status = 'Lỗi tracking: $err');
      },
    );
  }

  void _testStopTracking() {
    ref.read(locationServiceProvider).stopTracking();
    setState(() {
      _isTracking = false;
      _status = 'Đã dừng tracking (tổng $_updateCount lần update)';
    });
  }

  Future<void> _testUpdateSupabase() async {
    if (_lat == null || _lng == null) {
      setState(() => _status = 'Chưa có vị trí, hãy lấy vị trí trước');
      return;
    }
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      setState(() => _status = 'Chưa đăng nhập driver');
      return;
    }

    setState(() => _status = 'Đang update lên Supabase...');
    try {
      final driverService = ref.read(driverServiceProvider);
      final driver = await driverService.getDriverByUserId(currentUser.id);
      if (driver == null) {
        setState(() => _status = 'Không tìm thấy driver profile');
        return;
      }

      await driverService.updateLocation(
        driverId: driver.id,
        lat: _lat!,
        lng: _lng!,
      );

      await driverService.insertHistoryPoint(
        driverId: driver.id,
        lat: _lat!,
        lng: _lng!,
      );

      setState(() => _status = 'OK: Đã update drivers + insert history');
    } catch (e) {
      setState(() => _status = 'Lỗi Supabase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
      title: Row(
        children: [
          const Icon(Icons.gps_fixed_rounded, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Text('Test GPS', style: AppTextStyles.headingSmall),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _status.contains('OK')
                    ? AppColors.success.withValues(alpha: 0.1)
                    : _status.contains('Lỗi')
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.accentLight,
                borderRadius: AppRadius.sm,
              ),
              child: Text(
                _status,
                style: AppTextStyles.bodySmall.copyWith(
                  color: _status.contains('OK')
                      ? AppColors.success
                      : _status.contains('Lỗi')
                          ? AppColors.error
                          : AppColors.textSecondary,
                ),
              ),
            ),
            if (_lat != null && _lng != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Lat: ${_lat!.toStringAsFixed(6)}',
                style: AppTextStyles.mono.copyWith(fontSize: 12),
              ),
              Text(
                'Lng: ${_lng!.toStringAsFixed(6)}',
                style: AppTextStyles.mono.copyWith(fontSize: 12),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _buildButton('1. Xin quyền GPS', Icons.shield_outlined, _testPermission),
            _buildButton('2. Lấy vị trí hiện tại', Icons.my_location_rounded, _testGetPosition),
            _buildButton(
              _isTracking ? 'Đang tracking... ($_updateCount)' : '3. Bắt đầu tracking (30s)',
              Icons.play_arrow_rounded,
              _testStartTracking,
            ),
            _buildButton('4. Dừng tracking', Icons.stop_rounded, _testStopTracking),
            _buildButton('5. Update lên Supabase', Icons.cloud_upload_rounded, _testUpdateSupabase),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _testStopTracking();
            Navigator.of(context).pop();
          },
          child: Text('Đóng', style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent)),
        ),
      ],
    );
  }

  Widget _buildButton(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.bgLight,
        borderRadius: AppRadius.sm,
        child: InkWell(
          borderRadius: AppRadius.sm,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
