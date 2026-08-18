import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/location/driver_location_mode_store.dart';
import '../../../../core/location/driver_location_producer_policy.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/services/reverse_geocoding_service.dart';
import '../../../../core/utils/geo_utils.dart';
import 'driver_gps_debug_components.dart';
import 'driver_gps_debug_map.dart';
import 'driver_gps_debug_states.dart';
import 'driver_gps_location_actions.dart';

class DriverGpsDebugSheet extends ConsumerStatefulWidget {
  const DriverGpsDebugSheet({super.key});

  @override
  ConsumerState<DriverGpsDebugSheet> createState() =>
      _DriverGpsDebugSheetState();
}

class _DriverGpsDebugSheetState extends ConsumerState<DriverGpsDebugSheet> {
  static const _loadingAddress = 'Đang xác định địa chỉ…';
  static const _unknownAddress = 'Không xác định được địa chỉ';

  final ReverseGeocodingService _reverseGeocodingService =
      ReverseGeocodingService();
  final Map<String, String> _addresses = {};
  final Set<String> _pendingAddressKeys = {};

  bool _isLoading = true;
  DriverLocationMode? _applyingMode;
  String? _error;
  String? _successMessage;
  String _email = '';
  String? _driverProfileId;
  LatLng? _gpsPosition;
  LatLng? _demoPosition;
  LatLng? _storedPosition;
  double _offsetMeters = 0;

  bool get _hasOffset => _offsetMeters >= 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPosition());
  }

  @override
  void dispose() {
    _reverseGeocodingService.dispose();
    super.dispose();
  }

  Future<void> _loadPosition() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _successMessage = null;
      });
    }

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw const _GpsDebugException(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }

      final driver = await ref
          .read(driverServiceProvider)
          .getDriverByUserId(currentUser.id);
      if (driver == null) {
        throw const _GpsDebugException('Không tìm thấy hồ sơ tài xế.');
      }

      final position = await ref
          .read(locationServiceProvider)
          .getCurrentPosition();
      if (position == null) {
        throw const _GpsDebugException(
          'Không lấy được GPS. Hãy bật dịch vụ vị trí và cấp quyền cho ứng dụng.',
        );
      }

      final gps = LatLng(position.latitude, position.longitude);
      final demo = GeoUtils.applyTestDriverOffset(
        email: currentUser.email,
        lat: gps.latitude,
        lng: gps.longitude,
      );
      final stored = _storedPoint(driver.currentLat, driver.currentLng);

      if (!mounted) return;
      setState(() {
        _email = currentUser.email ?? '';
        _driverProfileId = driver.id;
        _gpsPosition = gps;
        _demoPosition = demo;
        _storedPosition = stored;
        _offsetMeters = _distance(gps, demo);
        _isLoading = false;
      });
      unawaited(_resolveAddresses([gps, demo, stored]));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _readableError(error);
      });
    }
  }

  Future<void> _applyLocationMode(DriverLocationMode mode) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final profileId = _driverProfileId;
    final loadedGps = _gpsPosition;
    if (currentUser == null || profileId == null || loadedGps == null) return;

    setState(() {
      _applyingMode = mode;
      _error = null;
      _successMessage = null;
    });

    try {
      LatLng rawGps = loadedGps;
      if (mode == DriverLocationMode.deviceGps) {
        final position = await ref
            .read(locationServiceProvider)
            .getCurrentPosition();
        if (position == null) {
          throw const _GpsDebugException(
            'Không lấy được GPS. Hãy bật dịch vụ vị trí và cấp quyền cho ứng dụng.',
          );
        }
        rawGps = LatLng(position.latitude, position.longitude);
      } else if (!GeoUtils.hasTestDriverOffset(currentUser.email)) {
        throw const _GpsDebugException(
          'Tài khoản này chưa có vị trí demo TP.HCM.',
        );
      }

      final selected = mode.resolveRawGps(
        email: currentUser.email,
        lat: rawGps.latitude,
        lng: rawGps.longitude,
      );
      final demo = DriverLocationMode.demoHcm.resolveRawGps(
        email: currentUser.email,
        lat: rawGps.latitude,
        lng: rawGps.longitude,
      );

      await ref
          .read(locationIngestServiceProvider)
          .ingest(
            driverProfileId: profileId,
            lat: selected.latitude,
            lng: selected.longitude,
            force: true,
            prioritySync: true,
            coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
          );
      final refreshed = await ref
          .read(driverServiceProvider)
          .getDriverByUserId(currentUser.id);
      final stored = _storedPoint(refreshed?.currentLat, refreshed?.currentLng);
      if (stored == null || _distance(stored, selected) > 50) {
        throw const _GpsDebugException(
          'Chưa đồng bộ được vị trí đã chọn lên máy chủ. Chế độ GPS chưa thay đổi, vui lòng thử lại.',
        );
      }

      await DriverLocationModeStore().save(mode);

      if (!mounted) return;
      ref.read(driverLocationModeProvider.notifier).state = mode;
      setState(() {
        _gpsPosition = rawGps;
        _demoPosition = demo;
        _storedPosition = stored;
        _offsetMeters = _distance(rawGps, demo);
        _successMessage = mode == DriverLocationMode.deviceGps
            ? 'Đang dùng vị trí hiện tại để tính tuyến đường gần bạn.'
            : 'Đã chuyển về vị trí demo TP.HCM của tài khoản.';
      });
      unawaited(_resolveAddresses([rawGps, demo, stored]));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _readableError(error);
      });
    } finally {
      if (mounted) setState(() => _applyingMode = null);
    }
  }

  LatLng? _storedPoint(double? lat, double? lng) {
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }

  double _distance(LatLng from, LatLng to) {
    return GeoUtils.distanceMeters(
      fromLat: from.latitude,
      fromLng: from.longitude,
      toLat: to.latitude,
      toLng: to.longitude,
    );
  }

  String _addressFor(LatLng? position) {
    if (position == null) return _unknownAddress;
    return _addresses[_addressKey(position)] ?? _loadingAddress;
  }

  String _addressKey(LatLng position) {
    return '${position.latitude.toStringAsFixed(6)},'
        '${position.longitude.toStringAsFixed(6)}';
  }

  Future<void> _resolveAddresses(Iterable<LatLng?> positions) async {
    final uniquePositions = <String, LatLng>{};
    for (final position in positions) {
      if (position == null) continue;
      uniquePositions.putIfAbsent(_addressKey(position), () => position);
    }

    for (final entry in uniquePositions.entries) {
      if (_addresses.containsKey(entry.key) ||
          !_pendingAddressKeys.add(entry.key)) {
        continue;
      }

      var address = _unknownAddress;
      try {
        final result = await _reverseGeocodingService.resolve(entry.value);
        final resolvedAddress = result.displayAddress.trim();
        if (resolvedAddress.isNotEmpty) address = resolvedAddress;
      } catch (_) {
        address = _unknownAddress;
      } finally {
        _pendingAddressKeys.remove(entry.key);
      }

      _addresses[entry.key] = address;
      if (mounted) setState(() {});
    }
  }

  String _readableError(Object error) {
    if (error is _GpsDebugException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            DriverGpsSheetHeader(email: _email),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.sm,
                  AppSpacing.screenH,
                  AppSpacing.xl2,
                ),
                child: AnimatedSwitcher(
                  duration: AppDuration.normal,
                  child: _buildContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const DriverGpsLoadingState(key: ValueKey('loading'));
    }
    if (_gpsPosition == null || _demoPosition == null) {
      return DriverGpsErrorState(
        key: const ValueKey('error'),
        message: _error ?? 'Chưa có dữ liệu vị trí.',
        onRetry: _loadPosition,
      );
    }

    final gps = _gpsPosition!;
    final demo = _demoPosition!;
    final stored = _storedPosition;
    final locationMode = ref.watch(driverLocationModeProvider);
    final expected = locationMode == DriverLocationMode.deviceGps ? gps : demo;
    final storedDistance = stored == null ? null : _distance(stored, expected);
    final isStoredMatched = storedDistance != null && storedDistance <= 50;

    return Column(
      key: const ValueKey('content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DriverGpsDemoBanner(
          locationMode: locationMode,
          hasOffset: _hasOffset,
          isDemoAccount: GeoUtils.hasConfiguredTestDriverOffset(_email),
          offsetMeters: _offsetMeters,
        ),
        const SizedBox(height: AppSpacing.lg),
        DriverGpsDebugMap(
          gpsPosition: gps,
          demoPosition: demo,
          hasOffset: _hasOffset,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Đối chiếu vị trí', style: AppTextStyles.headingSmall),
        const SizedBox(height: AppSpacing.sm),
        DriverGpsCoordinateCard(
          icon: Icons.my_location_rounded,
          color: AppColors.info,
          title: 'GPS thiết bị',
          subtitle: 'Vị trí thật do thiết bị cung cấp',
          address: _addressFor(gps),
        ),
        const SizedBox(height: AppSpacing.sm),
        DriverGpsCoordinateCard(
          icon: Icons.local_shipping_rounded,
          color: AppColors.accent,
          title: 'Vị trí demo TP.HCM',
          subtitle: _hasOffset
              ? 'Tọa độ cố định riêng của tài khoản tài xế'
              : 'Tài khoản này chưa có vị trí demo',
          address: _addressFor(demo),
        ),
        const SizedBox(height: AppSpacing.sm),
        DriverGpsStoredCard(
          position: stored,
          distanceMeters: storedDistance,
          isMatched: isStoredMatched,
          address: _addressFor(stored),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          DriverGpsInlineMessage(
            icon: Icons.error_outline_rounded,
            color: AppColors.error,
            message: _error!,
          ),
        ],
        if (_successMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          DriverGpsInlineMessage(
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
            message: _successMessage!,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        DriverGpsLocationActions(
          applyingMode: _applyingMode,
          canUseDemo: GeoUtils.hasTestDriverOffset(_email),
          onUseDeviceGps: () =>
              _applyLocationMode(DriverLocationMode.deviceGps),
          onUseDemoHcm: () => _applyLocationMode(DriverLocationMode.demoHcm),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Bạn có thể chuyển giữa GPS hiện tại và điểm demo TP.HCM bất cứ lúc nào.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _GpsDebugException implements Exception {
  const _GpsDebugException(this.message);

  final String message;
}
