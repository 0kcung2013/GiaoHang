import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/geo_utils.dart';

/// Upload vị trí driver lên Supabase (bảng drivers).
/// Gọi mỗi khi driver di chuyển để customer có thể track realtime.
class DriverLocationService {
  DriverLocationService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Cập nhật current_lat / current_lng trong bảng drivers.
  /// driverId = users.id (không phải drivers.id).
  ///
  /// Tài khoản test `taixe2@gmail.com` tự lệch ~3km so với GPS thật
  /// để demo tìm tài xế gần nhất trên cùng một thiết bị.
  Future<void> updateLocation({
    required String driverId,
    required double lat,
    required double lng,
  }) async {
    try {
      final email = _supabase.auth.currentUser?.email;
      final adjusted = GeoUtils.applyTestDriverOffset(
        email: email,
        lat: lat,
        lng: lng,
      );

      // 1. Cập nhật current_lat / current_lng trong bảng drivers
      final response = await _supabase
          .from('drivers')
          .update({
            'current_lat': adjusted.latitude,
            'current_lng': adjusted.longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', driverId)
          .select('id')
          .maybeSingle();

      if (response != null) {
        final profileId = response['id'] as String;

        // 2. Ghi log vào bảng locations cho lịch sử tracking
        try {
          await _supabase.from('locations').insert({
            'driver_id': profileId,
            'lat': adjusted.latitude,
            'lng': adjusted.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('[DriverLocation] Failed to insert to locations: $e');
        }

        // 3. Ghi log vào bảng driver_locations cho tương thích DriverService
        try {
          await _supabase.from('driver_locations').insert({
            'driver_id': profileId,
            'lat': adjusted.latitude,
            'lng': adjusted.longitude,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('[DriverLocation] Failed to insert to driver_locations: $e');
        }
      } else {
        debugPrint('[DriverLocation] No driver profile found for user_id: $driverId');
      }
    } catch (e) {
      debugPrint('[DriverLocation] Failed to upload location: $e');
    }
  }
}
