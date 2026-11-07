import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/location/driver_foreground_location_service.dart';
import '../../../../core/location/driver_location_mode_store.dart';
import '../../../../core/location/driver_location_producer_policy.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/location/driver_presence_strings.dart';
import '../../../../core/services/reverse_geocoding_service.dart';
import '../../../../core/utils/geo_utils.dart';
import 'driver_gps_debug_components.dart';
import 'driver_gps_debug_map.dart';
import 'driver_gps_debug_states.dart';
import 'driver_gps_location_actions.dart';
import 'driver_gps_debug_strings.dart';

import 'driver_gps_debug_providers.dart';

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
  bool _profileLoading = true;
  String? _profileError;
  int _loadGeneration = 0;
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
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _successMessage = null;
        _profileLoading = true;
        _profileError = null;
      });
    }

    try {
      final currentUser = ref.read(driverGpsDebugUserProvider)();
      if (currentUser == null) {
        throw const _GpsDebugException(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }

      setState(() => _email = currentUser.email ?? '');
      unawaited(_loadServerProfile(currentUser.id, generation));
      final location = ref.read(locationServiceProvider);
      final position = await location.getCurrentPosition().timeout(
        const Duration(seconds: 8),
        onTimeout: () =>
            throw const _GpsDebugException(DriverPresenceStrings.gpsTimedOut),
      );
      if (position == null) {
        throw _GpsDebugException(
          location.lastFailure?.message ??
              DriverPresenceStrings.positionUnavailable,
        );
      }

      final gps = LatLng(position.latitude, position.longitude);
      final demo = GeoUtils.applyTestDriverOffset(
        email: currentUser.email,
        lat: gps.latitude,
        lng: gps.longitude,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _gpsPosition = gps;
        _demoPosition = demo;
        _offsetMeters = _distance(gps, demo);
        _isLoading = false;
      });
      unawaited(
        _resolveAddresses([
          gps,
          demo,
          DriverLocationMode.demoCurrentPosition.resolveRawGps(
            email: _email,
            lat: gps.latitude,
            lng: gps.longitude,
          ),
        ]),
      );
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _error = _readableError(error);
      });
    }
  }

  Future<void> _loadServerProfile(String userId, int generation) async {
    try {
      final driver = await ref
          .read(driverGpsDebugProfileProvider)(userId)
          .timeout(const Duration(seconds: 8));
      if (!mounted || generation != _loadGeneration) return;
      if (driver == null) {
        throw const _GpsDebugException(DriverGpsDebugStrings.profileMissing);
      }
      final stored = _storedPoint(driver.currentLat, driver.currentLng);
      setState(() {
        _driverProfileId = driver.id;
        _storedPosition = stored;
      });
      unawaited(_resolveAddresses([stored]));
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(
        () => _profileError = error is TimeoutException
            ? DriverGpsDebugStrings.profileTimedOut
            : DriverGpsDebugStrings.profileUnavailable,
      );
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _profileLoading = false);
      }
    }
  }

  Future<void> _applyLocationMode(DriverLocationMode mode) async {
    final currentUser = ref.read(driverGpsDebugUserProvider)();
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
      if (mode != DriverLocationMode.demoHcm) {
        final location = ref.read(locationServiceProvider);
        final position = await location.getCurrentPosition();
        if (position == null) {
          throw _GpsDebugException(
            location.lastFailure?.message ??
                DriverPresenceStrings.positionUnavailable,
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

      if (mode != DriverLocationMode.deviceGps) {
        await DriverForegroundLocationService.stop();
      }

      await ref
          .read(locationIngestServiceProvider)
          .ingest(
            driverProfileId: profileId,
            lat: selected.latitude,
            lng: selected.longitude,
            force: true,
            prioritySync: true,
            coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
          )
          .timeout(const Duration(seconds: 12));
      final refreshed = await ref
          .read(driverServiceProvider)
          .getDriverByUserId(currentUser.id)
          .timeout(const Duration(seconds: 8));
      final stored = _storedPoint(refreshed?.currentLat, refreshed?.currentLng);
      if (stored == null || _distance(stored, selected) > 50) {
        throw const _GpsDebugException(
          'Chưa đồng bộ được vị trí đã chọn lên máy chủ. Chế độ GPS chưa thay đổi, vui lòng thử lại.',
        );
      }

      await DriverLocationModeStore().save(mode);

      if (!mounted) return;
      ref.read(driverLocationModeProvider.notifier).state = mode;
      ref.read(driverPhysicalPositionProvider.notifier).state = selected;
      ref.read(driverArrivalFixProvider.notifier).state = null;
      setState(() {
        _gpsPosition = rawGps;
        _demoPosition = demo;
        _storedPosition = stored;
        _offsetMeters = _distance(rawGps, demo);
        _successMessage = switch (mode) {
          DriverLocationMode.deviceGps =>
            'Đang dùng GPS thiết bị để theo dõi di chuyển thực tế.',
          DriverLocationMode.demoCurrentPosition =>
            'Đã bật mô phỏng tuyến từ vị trí hiện tại.',
          DriverLocationMode.demoHcm =>
            'Đã chuyển về vị trí demo TP.HCM của tài khoản.',
        };
      });
      unawaited(_resolveAddresses([rawGps, demo, selected, stored]));
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
    final currentDemo = DriverLocationMode.demoCurrentPosition.resolveRawGps(
      email: _email,
      lat: gps.latitude,
      lng: gps.longitude,
    );
    final isCurrentDemo =
        locationMode == DriverLocationMode.demoCurrentPosition;
    final selectedDemo = isCurrentDemo ? currentDemo : demo;
    final selectedOffsetMeters = _distance(gps, selectedDemo);
    final expected = locationMode.resolveRawGps(
      email: _email,
      lat: gps.latitude,
      lng: gps.longitude,
    );
    final storedDistance = stored == null ? null : _distance(stored, expected);
    final isStoredMatched = storedDistance != null && storedDistance <= 50;

    return Column(
      key: const ValueKey('content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DriverGpsDemoBanner(
          locationMode: locationMode,
          hasOffset: selectedOffsetMeters >= 1,
          isDemoAccount: GeoUtils.hasConfiguredTestDriverOffset(_email),
          offsetMeters: selectedOffsetMeters,
        ),
        const SizedBox(height: AppSpacing.lg),
        DriverGpsDebugMap(
          gpsPosition: gps,
          demoPosition: selectedDemo,
          hasOffset: selectedOffsetMeters >= 1,
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
          title: isCurrentDemo
              ? DriverGpsDebugStrings.currentDemoTitle
              : 'Vị trí demo TP.HCM',
          subtitle: isCurrentDemo
              ? (selectedOffsetMeters >= 1
                    ? DriverGpsDebugStrings.currentDemoOffset(
                        selectedOffsetMeters,
                      )
                    : DriverGpsDebugStrings.currentDemoAtAnchor)
              : _hasOffset
              ? 'Tọa độ cố định riêng của tài khoản tài xế'
              : 'Tài khoản này chưa có vị trí demo',
          address: _addressFor(selectedDemo),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_profileLoading)
          const DriverGpsInlineMessage(
            icon: Icons.cloud_download_rounded,
            color: AppColors.info,
            message: DriverGpsDebugStrings.profileLoading,
          )
        else if (_profileError != null)
          DriverGpsInlineMessage(
            icon: Icons.cloud_off_rounded,
            color: AppColors.warning,
            message: _profileError!,
          )
        else
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
          enabled:
              _driverProfileId != null &&
              !_profileLoading &&
              _profileError == null,
          applyingMode: _applyingMode,
          canUseDemo: GeoUtils.hasTestDriverOffset(_email),
          onUseDemoCurrentPosition: () =>
              _applyLocationMode(DriverLocationMode.demoCurrentPosition),
          onUseDemoHcm: () => _applyLocationMode(DriverLocationMode.demoHcm),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Chọn vị trí bắt đầu mô phỏng. Xe sẽ tự chạy theo tuyến khi bắt đầu chặng.',
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
