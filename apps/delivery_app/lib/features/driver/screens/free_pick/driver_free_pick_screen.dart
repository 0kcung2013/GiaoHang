import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../core/location/driver_location_producer_policy.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/services/free_pick_service.dart';
import '../home/utils/driver_dashboard_location.dart';
import '../home/utils/driver_home_formatters.dart';
import '../home/widgets/driver_state_widgets.dart';
import 'free_pick_providers.dart';
import 'widgets/free_pick_map_canvas.dart';
import 'widgets/free_pick_order_panel.dart';
import 'widgets/free_pick_status_overlay.dart';

class DriverFreePickScreen extends ConsumerStatefulWidget {
  const DriverFreePickScreen({super.key});

  @override
  ConsumerState<DriverFreePickScreen> createState() =>
      _DriverFreePickScreenState();
}

class _DriverFreePickScreenState extends ConsumerState<DriverFreePickScreen> {
  final _mapController = MapController();
  Timer? _searchDebounce;
  List<OrderModel> _orders = const [];
  OrderModel? _selectedOrder;
  FreePickViewport? _lastViewport;
  LatLng? _driverPosition;
  bool _isEnabled = false;
  bool _isLoading = false;
  bool _isClaiming = false;
  bool _didCenterOnce = false;
  int _requestSerial = 0;
  String? _error;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const DriverMessageState(
        icon: Icons.lock_outline_rounded,
        title: 'Cần đăng nhập',
        message: 'Đăng nhập bằng tài khoản tài xế để sử dụng FreePick.',
      );
    }

    final driverAsync = ref.watch(driverByUserIdProvider(user.id));
    return driverAsync.when(
      loading: () => const DriverLoadingState(),
      error: (_, _) => DriverErrorState(
        onRetry: () => ref.invalidate(driverByUserIdProvider(user.id)),
      ),
      data: (driver) {
        if (driver == null) return const MissingDriverProfileState();
        final ordersAsync = ref.watch(driverOrdersProvider(driver.userId));
        final offersAsync = ref.watch(availableOrdersProvider(driver.userId));
        final currentPosition = ref.watch(currentPositionProvider).valueOrNull;
        final locationMode = ref.watch(driverLocationModeProvider);
        final position = resolveDriverDashboardPosition(
          locationMode: locationMode,
          email: user.email,
          rawLat: currentPosition?.latitude,
          rawLng: currentPosition?.longitude,
          storedLat: driver.currentLat,
          storedLng: driver.currentLng,
        );
        final hasActiveOrder =
            ordersAsync.valueOrNull?.any(isActiveDriverOrder) ?? false;
        final hasActiveOffer = offersAsync.valueOrNull?.isNotEmpty ?? false;
        final enabled =
            driver.isAvailable && !hasActiveOrder && !hasActiveOffer;
        _syncRuntimeState(position: position, enabled: enabled);

        return Stack(
          children: [
            FreePickMapCanvas(
              mapController: _mapController,
              driverPosition: position,
              orders: enabled ? _orders : const [],
              selectedOrderId: _selectedOrder?.id,
              onMapSettled: _onMapSettled,
              onOrderSelected: (order) {
                setState(() => _selectedOrder = order);
              },
              onLocate: _locateDriver,
            ),
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: Align(
                alignment: Alignment.topCenter,
                child: FreePickStatusOverlay(
                  count: enabled ? _orders.length : 0,
                  isLoading: _isLoading,
                  isEnabled: enabled,
                  error: _error,
                ),
              ),
            ),
            if (_selectedOrder != null && enabled)
              Align(
                alignment: Alignment.bottomCenter,
                child: FreePickOrderPanel(
                  order: _selectedOrder!,
                  isClaiming: _isClaiming,
                  onClaim: _claimSelectedOrder,
                  driverLat: position?.latitude,
                  driverLng: position?.longitude,
                ),
              ),
          ],
        );
      },
    );
  }

  void _syncRuntimeState({required LatLng? position, required bool enabled}) {
    _driverPosition = position;
    _isEnabled = enabled;
    if (position != null && !_didCenterOnce) {
      _didCenterOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(position, 13);
      });
    }
  }

  void _onMapSettled(FreePickViewport viewport) {
    _lastViewport = viewport;
    _searchDebounce?.cancel();
    if (!_isEnabled) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 550),
      () => _loadViewport(viewport),
    );
  }

  Future<void> _loadViewport(FreePickViewport viewport) async {
    final serial = ++_requestSerial;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final orders = await ref
          .read(freePickServiceProvider)
          .getOrdersInViewport(viewport);
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _orders = orders;
        if (_selectedOrder != null &&
            !orders.any((order) => order.id == _selectedOrder!.id)) {
          _selectedOrder = null;
        }
      });
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && serial == _requestSerial) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _locateDriver() async {
    var position = _driverPosition;
    if (position == null) {
      final raw = await ref.refresh(currentPositionProvider.future);
      if (!mounted) return;
      final locationMode = ref.read(driverLocationModeProvider);
      final email = Supabase.instance.client.auth.currentUser?.email;
      position = raw == null
          ? null
          : locationMode.resolveRawGps(
              email: email,
              lat: raw.latitude,
              lng: raw.longitude,
            );
    }
    if (position == null) {
      _showMessage('Chưa xác định được vị trí tài xế.', isError: true);
      return;
    }
    _mapController.move(position, 13);
  }

  Future<void> _claimSelectedOrder() async {
    final order = _selectedOrder;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (order == null || userId == null || _isClaiming) return;
    setState(() => _isClaiming = true);
    try {
      await ref.read(freePickServiceProvider).claimOrder(order.id);
      ref.invalidate(driverOrdersProvider(userId));
      ref.invalidate(availableOrdersProvider(userId));
      if (!mounted) return;
      setState(() {
        _orders = _orders.where((item) => item.id != order.id).toList();
        _selectedOrder = null;
      });
      _showMessage('Đã nhận ${displayOrderCode(order)}.');
      final viewport = _lastViewport;
      if (viewport != null) unawaited(_loadViewport(viewport));
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('Exception: ', '')),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
