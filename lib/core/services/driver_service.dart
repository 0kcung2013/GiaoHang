import 'package:supabase_flutter/supabase_flutter.dart';

import '../location/location_ingest_service.dart';
import '../models/driver_location_model.dart';
import '../models/driver_model.dart';

class DriverService {
  DriverService({
    SupabaseClient? client,
    LocationIngestService? locationIngest,
  })  : _supabase = client ?? Supabase.instance.client,
        _locationIngest = locationIngest ?? LocationIngestService();

  final SupabaseClient _supabase;
  final LocationIngestService _locationIngest;

  static const String _driversTable = 'drivers';
  static const String _ordersTable = 'orders';
  static const String _locationsTable = 'driver_locations';

  Future<DriverModel?> getDriverById(String driverId) async {
    try {
      final response = await _supabase
          .from(_driversTable)
          .select()
          .eq('id', driverId)
          .maybeSingle();

      if (response == null) return null;
      return DriverModel.fromJson(response);
    } catch (error) {
      throw Exception('Failed to load driver by id: $error');
    }
  }

  Future<DriverModel?> getDriverByUserId(String userId) async {
    try {
      final response = await _supabase
          .from(_driversTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return DriverModel.fromJson(response);
    } catch (error) {
      throw Exception('Failed to load driver by user id: $error');
    }
  }

  Future<void> updateAvailability(String driverId, bool isAvailable) async {
    try {
      await _supabase
          .from(_driversTable)
          .update({
            'is_available': isAvailable,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);
    } catch (error) {
      throw Exception('Failed to update availability: $error');
    }
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
      await _locationIngest.ingest(
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
      await _supabase.from(_locationsTable).insert({
        'driver_id': driverId,
        'lat': lat,
        'lng': lng,
        'heading': heading,
        'speed': speed,
        'is_active': isActive,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      throw Exception('Failed to insert location history: $error');
    }
  }

  Future<DriverLocationModel?> getLastLocation(String driverId) async {
    try {
      final response = await _supabase
          .from(_locationsTable)
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return DriverLocationModel.fromJson(response);
    } catch (error) {
      throw Exception('Failed to get last location: $error');
    }
  }

  /// Profile tài xế cho khách (tracking): ưu tiên RPC public, fallback join thủ công.
  Future<DriverModel?> getPublicDriverForOrder(String orderId) async {
    if (orderId.trim().isEmpty) return null;

    try {
      final rpcResult = await _supabase.rpc(
        'get_public_driver_for_order',
        params: {'p_order_id': orderId},
      );
      if (rpcResult != null) {
        final map = Map<String, dynamic>.from(rpcResult as Map);
        return DriverModel.fromPublicProfileJson(map);
      }
    } catch (_) {
      // RPC chưa deploy hoặc auth/policy — fallback client join.
    }

    return _getDriverForOrderFallback(orderId);
  }

  Future<DriverModel?> getDriverForOrder(String orderId) async {
    return getPublicDriverForOrder(orderId);
  }

  Future<DriverModel?> _getDriverForOrderFallback(String orderId) async {
    try {
      final order = await _supabase
          .from(_ordersTable)
          .select('driver_id')
          .eq('id', orderId)
          .maybeSingle();

      if (order == null) return null;

      final driverUserId = order['driver_id']?.toString();
      if (driverUserId == null || driverUserId.isEmpty) {
        return null;
      }

      final response = await _supabase
          .from(_driversTable)
          .select()
          .eq('user_id', driverUserId)
          .maybeSingle();

      if (response == null) return null;

      final driverMap = Map<String, dynamic>.from(response as Map);
      try {
        final user = await _supabase
            .from('users')
            .select('full_name, phone, avatar_url, email, created_at')
            .eq('id', driverUserId)
            .maybeSingle();
        if (user != null) {
          driverMap['full_name'] = user['full_name'];
          driverMap['phone'] = user['phone'];
          driverMap['avatar_url'] = user['avatar_url'];
          driverMap['email'] = user['email'];
          driverMap['member_since'] = user['created_at'];
        }
      } catch (_) {
        // RLS may block reading other users; card still shows vehicle fields.
      }

      return DriverModel.fromJson(driverMap);
    } catch (error) {
      throw Exception('Failed to load assigned driver for order: $error');
    }
  }
}
