import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/utils/geo_utils.dart';
import 'driver_gps_debug_components.dart';
import 'driver_gps_debug_map.dart';
import 'driver_gps_debug_states.dart';

class DriverGpsDebugSheet extends ConsumerStatefulWidget {
  const DriverGpsDebugSheet({super.key});

  @override
  ConsumerState<DriverGpsDebugSheet> createState() =>
      _DriverGpsDebugSheetState();
}

class _DriverGpsDebugSheetState extends ConsumerState<DriverGpsDebugSheet> {
  bool _isLoading = true;
  bool _isSyncing = false;
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

      if (!mounted) return;
      setState(() {
        _email = currentUser.email ?? '';
        _driverProfileId = driver.id;
        _gpsPosition = gps;
        _demoPosition = demo;
        _storedPosition = _storedPoint(driver.currentLat, driver.currentLng);
        _offsetMeters = _distance(gps, demo);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _readableError(error);
      });
    }
  }

  Future<void> _syncPosition() async {
    final gps = _gpsPosition;
    final profileId = _driverProfileId;
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (gps == null || profileId == null || currentUser == null) return;

    setState(() {
      _isSyncing = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await ref
          .read(locationIngestServiceProvider)
          .ingest(
            driverProfileId: profileId,
            lat: gps.latitude,
            lng: gps.longitude,
            force: true,
            prioritySync: true,
          );
      final refreshed = await ref
          .read(driverServiceProvider)
          .getDriverByUserId(currentUser.id);

      if (!mounted) return;
      setState(() {
        _storedPosition = _storedPoint(
          refreshed?.currentLat,
          refreshed?.currentLng,
        );
        _isSyncing = false;
        _successMessage = 'Đã đồng bộ vị trí lên hệ thống.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _error = 'Không thể đồng bộ vị trí: ${_readableError(error)}';
      });
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
    final storedDistance = stored == null ? null : _distance(stored, demo);
    final isStoredMatched = storedDistance != null && storedDistance <= 50;

    return Column(
      key: const ValueKey('content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DriverGpsDemoBanner(
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
        Text('Đối chiếu tọa độ', style: AppTextStyles.headingSmall),
        const SizedBox(height: AppSpacing.sm),
        DriverGpsCoordinateCard(
          icon: Icons.my_location_rounded,
          color: AppColors.info,
          title: 'GPS thiết bị',
          subtitle: 'Vị trí thật do thiết bị cung cấp',
          position: gps,
        ),
        const SizedBox(height: AppSpacing.sm),
        DriverGpsCoordinateCard(
          icon: Icons.local_shipping_rounded,
          color: AppColors.accent,
          title: 'Vị trí gửi lên hệ thống',
          subtitle: _hasOffset
              ? 'Đã áp offset riêng cho taixe2'
              : 'Không áp offset demo',
          position: demo,
        ),
        const SizedBox(height: AppSpacing.sm),
        DriverGpsStoredCard(
          position: stored,
          distanceMeters: storedDistance,
          isMatched: isStoredMatched,
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
        _buildActions(),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Offset demo chỉ bật khi chạy debug và tự tắt trong bản release.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isSyncing ? null : _loadPosition,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Đo lại GPS'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _isSyncing ? null : _syncPosition,
              icon: Icon(
                _isSyncing
                    ? Icons.hourglass_top_rounded
                    : Icons.cloud_upload_rounded,
              ),
              label: Text(_isSyncing ? 'Đang lưu...' : 'Đồng bộ'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                disabledBackgroundColor: AppColors.accentLight,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
              ),
            ),
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
