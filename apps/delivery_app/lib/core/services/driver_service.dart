import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../location/driver_location_producer_policy.dart';
import '../location/location_ingest_service.dart';
import '../models/driver_location_model.dart';
import '../utils/geo_utils.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

typedef DriverRpcInvoker =
    Future<dynamic> Function(String name, Map<String, dynamic> params);

typedef DriverLocationPublisher =
    Future<void> Function({
      required String driverProfileId,
      required double lat,
      required double lng,
      double? heading,
      double? speed,
    });

class DriverOnlinePinStatus {
  const DriverOnlinePinStatus({required this.isConfigured, this.lockedUntil});

  final bool isConfigured;
  final DateTime? lockedUntil;

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now().toUtc());
}

class DriverOnlinePinException implements Exception {
  const DriverOnlinePinException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DriverService {
  DriverService({
    SupabaseClient? client,
    LocationIngestService? locationIngest,
    DriverRpcInvoker? rpcInvoker,
    DriverLocationPublisher? locationPublisher,
  }) : _supabase = client ?? Supabase.instance.client,
       _locationIngest =
           locationIngest ??
           (locationPublisher == null ? LocationIngestService() : null),
       _rpcInvoker = rpcInvoker,
       _locationPublisher = locationPublisher;

  final SupabaseClient _supabase;
  LocationIngestService? _locationIngest;
  final DriverRpcInvoker? _rpcInvoker;
  final DriverLocationPublisher? _locationPublisher;
  final Map<String, String?> _debugEmailByUserId = <String, String?>{};

  LocationIngestService get _locationPipeline {
    return _locationIngest ??= LocationIngestService(client: _supabase);
  }

  static const String _driversTable = 'drivers';
  static const String driverOperationalSelection =
      'id, user_id, vehicle_type, license_plate, is_available, current_lat, '
      'current_lng, updated_at, total_deliveries, approval_status, '
      'vehicle_brand_model, vehicle_color, verified_at, submitted_at, '
      'location_updated_at, acceptance_locked_until';

  Future<DriverModel?> getDriverById(String driverId) async {
    try {
      final response = await _supabase
          .from(_driversTable)
          .select(driverOperationalSelection)
          .eq('id', driverId)
          .maybeSingle();

      if (response == null) return null;
      return DriverModel.fromJson(response);
    } catch (error) {
      throw Exception('Failed to load driver by id: $error');
    }
  }

  Future<DriverModel?> getDriverByUserId(String userId) async {
    if (_supabase.auth.currentUser?.id != userId) return null;
    return getMyDriverAccountProfile();
  }

  Future<DriverModel?> getMyDriverAccountProfile() async {
    try {
      final response = await _supabase.rpc('get_my_driver_account_profile');

      if (response == null) return null;
      return DriverModel.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (error) {
      throw Exception('Failed to load my driver account profile: $error');
    }
  }

  Future<void> updateAvailability(bool isAvailable) async {
    try {
      await _invokeRpc('set_driver_availability', {
        'p_is_available': isAvailable,
      });
    } catch (error) {
      throw Exception('Failed to update availability: $error');
    }
  }

  Future<DriverOnlinePinStatus> getOnlinePinStatus() async {
    try {
      final response = await _invokeRpc('get_driver_online_pin_status', {});
      final data = Map<String, dynamic>.from(response as Map);
      return DriverOnlinePinStatus(
        isConfigured: data['is_configured'] == true,
        lockedUntil: DateTime.tryParse(data['locked_until']?.toString() ?? ''),
      );
    } catch (error) {
      throw Exception('Không thể kiểm tra mã PIN Online: $error');
    }
  }

  Future<void> configureOnlinePin(String pin) async {
    try {
      await _invokeRpc('configure_driver_online_pin', {'p_pin': pin});
    } catch (error) {
      throw Exception('Không thể tạo mã PIN Online: $error');
    }
  }

  /// Ghi GPS mới trước, sau đó bật Online và đánh thức hàng chờ trong một RPC.
  Future<String?> setOnlineWithLocation({
    required String driverProfileId,
    required double lat,
    required double lng,
    required String pin,
    double? heading,
    double? speed,
    LocationIngestCoordinateSpace coordinateSpace =
        LocationIngestCoordinateSpace.rawGps,
  }) async {
    try {
      final adjusted = coordinateSpace.shouldApplyDemoOffset
          ? GeoUtils.applyTestDriverOffset(
              email: _supabase.auth.currentUser?.email,
              lat: lat,
              lng: lng,
            )
          : null;
      final effectiveLat = adjusted?.latitude ?? lat;
      final effectiveLng = adjusted?.longitude ?? lng;

      await _publishLocation(
        driverProfileId: driverProfileId,
        lat: effectiveLat,
        lng: effectiveLng,
        heading: heading,
        speed: speed,
      );

      final response = await _invokeRpc('set_driver_online_with_location', {
        'p_lat': effectiveLat,
        'p_lng': effectiveLng,
        'p_pin': pin,
      });
      final data = Map<String, dynamic>.from(response as Map);
      final status = data['status']?.toString();
      if (status == 'invalid_pin') {
        final remaining = (data['remaining_attempts'] as num?)?.toInt() ?? 0;
        throw DriverOnlinePinException(
          'Mã PIN không đúng. Bạn còn $remaining lần thử.',
        );
      }
      if (status == 'locked') {
        final lockedUntil = DateTime.tryParse(
          data['locked_until']?.toString() ?? '',
        );
        throw DriverOnlinePinException(_lockedPinMessage(lockedUntil));
      }
      if (status == 'pin_not_configured') {
        throw const DriverOnlinePinException(
          'Bạn cần tạo mã PIN Online trước khi nhận đơn.',
        );
      }
      if (status != 'online') {
        throw const DriverOnlinePinException(
          'Không thể xác thực mã PIN Online. Vui lòng thử lại.',
        );
      }

      final offeredOrderId = data['offered_order_id']?.toString().trim();
      return offeredOrderId == null ||
              offeredOrderId.isEmpty ||
              offeredOrderId == 'null'
          ? null
          : offeredOrderId;
    } catch (error) {
      if (error is DriverOnlinePinException) rethrow;
      throw Exception('Failed to go online with current location: $error');
    }
  }

  static String _lockedPinMessage(DateTime? lockedUntil) {
    if (lockedUntil == null) {
      return 'Mã PIN tạm khóa do nhập sai nhiều lần. Vui lòng thử lại sau.';
    }
    final remaining = lockedUntil.difference(DateTime.now().toUtc());
    final minutes =
        remaining.inMinutes + (remaining.inSeconds % 60 == 0 ? 0 : 1);
    return 'Mã PIN tạm khóa. Vui lòng thử lại sau ${minutes.clamp(1, 5)} phút.';
  }

  Future<dynamic> _invokeRpc(String name, Map<String, dynamic> params) {
    final invoker = _rpcInvoker;
    if (invoker != null) return invoker(name, params);
    return _supabase.rpc(name, params: params);
  }

  Future<void> _publishLocation({
    required String driverProfileId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) {
    final publisher = _locationPublisher;
    if (publisher != null) {
      return publisher(
        driverProfileId: driverProfileId,
        lat: lat,
        lng: lng,
        heading: heading,
        speed: speed,
      );
    }
    return _locationPipeline.ingest(
      driverProfileId: driverProfileId,
      lat: lat,
      lng: lng,
      heading: heading,
      speed: speed,
      force: true,
      coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
    );
  }

  /// Cập nhật vị trí qua pipeline tối ưu (throttle + hot/history tách).
  /// [driverId] = `drivers.id` (profile).
  Future<void> updateLocation({
    required String driverId,
    required double lat,
    required double lng,
    double? heading,
  }) async {
    try {
      await _locationPipeline.ingest(
        driverProfileId: driverId,
        lat: lat,
        lng: lng,
        heading: heading,
      );
    } catch (error) {
      throw Exception('Failed to update location: $error');
    }
  }

  Future<void> insertHistoryPoint({
    required String driverId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    bool isActive = true,
  }) async {
    try {
      await _locationPipeline.ingest(
        driverProfileId: driverId,
        lat: lat,
        lng: lng,
        heading: heading,
        speed: speed,
        force: true,
      );
    } catch (error) {
      throw Exception('Failed to enqueue location history: $error');
    }
  }

  Future<DriverLocationModel?> getLastLocation(String driverId) async {
    try {
      final response = await _supabase
          .from(_driversTable)
          .select('id, current_lat, current_lng, location_updated_at')
          .eq('id', driverId)
          .maybeSingle();

      if (response == null ||
          response['current_lat'] == null ||
          response['current_lng'] == null) {
        return null;
      }
      return DriverLocationModel.fromJson({
        'id': 'latest:$driverId',
        'driver_id': driverId,
        'lat': response['current_lat'],
        'lng': response['current_lng'],
        'created_at': response['location_updated_at'],
        'is_active': true,
      });
    } catch (error) {
      throw Exception('Failed to get last location: $error');
    }
  }

  /// Profile tài xế cho khách (tracking) chỉ đi qua RPC theo đơn hàng.
  Future<DriverModel?> getPublicDriverForOrder(String orderId) async {
    if (orderId.trim().isEmpty) return null;

    try {
      final rpcResult = await _supabase.rpc(
        'get_public_driver_for_order',
        params: {'p_order_id': orderId},
      );
      if (rpcResult != null) {
        final map = Map<String, dynamic>.from(rpcResult as Map);
        return _hydrateDebugDemoEmail(DriverModel.fromPublicProfileJson(map));
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[DriverService] public order profile failed: $error');
      }
    }

    return null;
  }

  Future<DriverModel?> getDriverForOrder(String orderId) async {
    return getPublicDriverForOrder(orderId);
  }

  /// RPC public intentionally omits email. Only in debug, fetch it privately
  /// to recognize the three local GPS-demo accounts; it is never shown in UI.
  Future<DriverModel> _hydrateDebugDemoEmail(DriverModel driver) async {
    if (!kDebugMode ||
        !GeoUtils.enableTestDriverOffsets ||
        driver.email != null ||
        driver.userId.isEmpty) {
      return driver;
    }

    try {
      final hasCachedEmail = _debugEmailByUserId.containsKey(driver.userId);
      final email = hasCachedEmail
          ? _debugEmailByUserId[driver.userId]
          : await _loadDebugEmail(driver.userId);
      if (!GeoUtils.hasConfiguredTestDriverOffset(email)) return driver;
      return driver.copyWith(email: email);
    } catch (_) {
      // RLS can hide email. The driver app still publishes its demo point.
      return driver;
    }
  }

  Future<String?> _loadDebugEmail(String userId) async {
    final user = await _supabase
        .from('users')
        .select('email')
        .eq('id', userId)
        .maybeSingle();
    final email = user?['email']?.toString();
    _debugEmailByUserId[userId] = email;
    return email;
  }
}
