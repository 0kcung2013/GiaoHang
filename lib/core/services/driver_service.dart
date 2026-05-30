import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver_model.dart';

class DriverService {
  DriverService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _driversTable = 'drivers';
  static const String _ordersTable = 'orders';

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