import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Upload vị trí driver lên Supabase (bảng drivers).
/// Gọi mỗi khi driver di chuyển để customer có thể track realtime.
class DriverLocationService {
  DriverLocationService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Cập nhật current_lat / current_lng trong bảng drivers.
  /// driverId = users.id (không phải drivers.id).
  Future<void> updateLocation({
    required String driverId,
    required double lat,
    required double lng,
  }) async {
    try {
      await _supabase
          .from('drivers')
          .update({
            'current_lat': lat,
            'current_lng': lng,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', driverId);

      // Log cũng vào bảng locations cho lịch sử tracking
      await _supabase.from('locations').insert({
        'driver_id': driverId,
        'lat': lat,
        'lng': lng,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[DriverLocation] Failed to upload location: $e');
      // Không throw — lỗi upload vị trí không nên crash app
    }
  }
}
