import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver_location_model.dart';
import '../models/driver_model.dart';
import '../utils/geo_utils.dart';

class DriverService {
  DriverService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

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

  Future<void> updateLocation({
    required String driverId,
    required double lat,
    required double lng,
    double? heading,
  }) async {
    try {
      final email = _supabase.auth.currentUser?.email;
      final adjusted = GeoUtils.applyTestDriverOffset(
        email: email,
        lat: lat,
        lng: lng,
      );

      await _supabase
          .from(_driversTable)
          .update({
            'current_lat': adjusted.latitude,
            'current_lng': adjusted.longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);
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

  Future<DriverModel?> getDriverForOrder(String orderId) async {
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
      return DriverModel.fromJson(response);
    } catch (error) {
      throw Exception('Failed to load assigned driver for order: $error');
    }
  }
}
