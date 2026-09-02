import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/driver_wallet_providers.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/services/free_pick_service.dart';
import '../home/utils/driver_home_formatters.dart';
import '../home/widgets/driver_state_widgets.dart';
import 'free_pick_providers.dart';
import 'utils/free_pick_radius.dart';
import 'utils/free_pick_wallet_refresh.dart';
import 'widgets/free_pick_map_canvas.dart';
import 'widgets/free_pick_order_carousel.dart';
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
  List<OrderModel> _viewportOrders = const [];
  List<OrderModel> _orders = const [];
  OrderModel? _selectedOrder;
  FreePickViewport? _lastViewport;
  LatLng? _driverPosition;
  bool _isEnabled = false;
  bool _isLoading = false;
  bool _isClaiming = false;
  bool _didCenterOnce = false;
  double _radiusMeters = freePickDefaultRadiusMeters;
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
    ref.listen(driverWalletChangesProvider, (previous, next) {
      reloadFreePickAfterWalletChange(
        previousRevision: previous?.valueOrNull,
        nextRevision: next.valueOrNull,
        isEnabled: _isEnabled,
        viewport: _lastViewport,
        reload: (viewport) => unawaited(_loadViewport(viewport)),
      );
    });

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
        final position = currentPosition == null
            ? null
            : LatLng(currentPosition.latitude, currentPosition.longitude);
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
              searchRadiusMeters: _radiusMeters,
              selectedOrderId: _selectedOrder?.id,
              onMapSettled: _onMapSettled,
              onOrderSelected: _selectOrder,
              onLocate: _locateDriver,
              onRadiusIncrease: _increaseRadius,
              onRadiusDecrease: _decreaseRadius,
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
                  radiusMeters: _radiusMeters,
                  error: _error,
                ),
              ),
            ),
            if (_orders.isNotEmpty && _selectedOrder != null && enabled)
              Align(
                alignment: Alignment.bottomCenter,
                child: FreePickOrderCarousel(
                  orders: _orders,
                  selectedOrderId: _selectedOrder!.id,
                  isClaiming: _isClaiming,
                  onSelected: _selectOrder,
                  onClaim: _claimOrder,
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
        if (mounted) {
          _mapController.move(position, FreePickMapCanvas.overviewZoom);
        }
      });
    }
  }

  void _onMapSettled(FreePickViewport viewport) {
    _lastViewport = viewport;
    _searchDebounce?.cancel();
    if (!_isEnabled ||
        _driverPosition == null ||
        _radiusMeters <= freePickDefaultRadiusMeters) {
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 550),
      () => _loadViewport(viewport),
    );
  }

  Future<void> _loadViewport(FreePickViewport viewport) async {
    final position = _driverPosition;
    if (position == null) return;
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
      final freePickOrders = ordersSearchableInFreePick(
        orders,
        driverLat: position.latitude,
        driverLng: position.longitude,
        radiusMeters: _radiusMeters,
      );
      setState(() {
        _viewportOrders = orders;
        _orders = freePickOrders;
        final selectedId = _selectedOrder?.id;
        _selectedOrder = freePickOrders.isEmpty
            ? null
            : freePickOrders.firstWhere(
                (order) => order.id == selectedId,
                orElse: () => freePickOrders.first,
              );
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
    final raw = await ref.refresh(currentPositionProvider.future);
    if (!mounted) return;
    final position = raw == null ? null : LatLng(raw.latitude, raw.longitude);
    if (position == null) {
      _showMessage('Chưa xác định được vị trí tài xế.', isError: true);
      return;
    }
    _driverPosition = position;
    _fitSearchRadius();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bounds = _mapController.camera.visibleBounds;
      _onMapSettled(
        FreePickViewport(
          south: bounds.south,
          west: bounds.west,
          north: bounds.north,
          east: bounds.east,
        ),
      );
    });
  }

  void _increaseRadius() {
    _setRadius(increaseFreePickRadius(_radiusMeters));
  }

  void _decreaseRadius() {
    _setRadius(decreaseFreePickRadius(_radiusMeters));
  }

  void _setRadius(double nextRadius) {
    if (nextRadius == _radiusMeters) return;
    final position = _driverPosition;
    final filtered = position == null
        ? const <OrderModel>[]
        : ordersSearchableInFreePick(
            _viewportOrders,
            driverLat: position.latitude,
            driverLng: position.longitude,
            radiusMeters: nextRadius,
          );
    final selectedId = _selectedOrder?.id;
    setState(() {
      _radiusMeters = nextRadius;
      _orders = filtered;
      _selectedOrder = filtered.isEmpty
          ? null
          : filtered.firstWhere(
              (order) => order.id == selectedId,
              orElse: () => filtered.first,
            );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fitSearchRadius();
      final bounds = _mapController.camera.visibleBounds;
      _onMapSettled(
        FreePickViewport(
          south: bounds.south,
          west: bounds.west,
          north: bounds.north,
          east: bounds.east,
        ),
      );
    });
  }

  void _fitSearchRadius() {
    final position = _driverPosition;
    if (position == null) return;
    const distance = Distance();
    final boundary = <LatLng>[
      distance.offset(position, _radiusMeters, 0),
      distance.offset(position, _radiusMeters, 90),
      distance.offset(position, _radiusMeters, 180),
      distance.offset(position, _radiusMeters, 270),
    ];
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: boundary,
          padding: const EdgeInsets.fromLTRB(76, 120, 76, 108),
          maxZoom: FreePickMapCanvas.overviewZoom,
        ),
      );
    } catch (_) {
      _mapController.move(position, FreePickMapCanvas.overviewZoom);
    }
  }

  void _selectOrder(OrderModel order) {
    if (_selectedOrder?.id != order.id) {
      setState(() => _selectedOrder = order);
    }
  }

  Future<void> _claimOrder(OrderModel order) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _isClaiming) return;
    final selectedIndex = _orders.indexWhere((item) => item.id == order.id);
    setState(() => _selectedOrder = order);
    setState(() => _isClaiming = true);
    try {
      await ref.read(freePickServiceProvider).claimOrder(order.id);
      ref.invalidate(driverOrdersProvider(userId));
      ref.invalidate(availableOrdersProvider(userId));
      if (!mounted) return;
      setState(() {
        _viewportOrders = _viewportOrders
            .where((item) => item.id != order.id)
            .toList(growable: false);
        final remaining = _orders.where((item) => item.id != order.id).toList();
        _orders = remaining;
        _selectedOrder = remaining.isEmpty
            ? null
            : remaining[selectedIndex.clamp(0, remaining.length - 1)];
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
