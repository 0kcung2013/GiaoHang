import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_delivery_arrival.dart';

typedef DeliveryArrivalInvoke =
    Future<dynamic> Function(String name, Map<String, dynamic> params);

class DriverDeliveryArrivalRepository {
  DriverDeliveryArrivalRepository({
    SupabaseClient? client,
    DeliveryArrivalInvoke? invoke,
  }) : _invoke =
           invoke ??
           ((name, params) =>
               (client ?? Supabase.instance.client).rpc(name, params: params));
  final DeliveryArrivalInvoke _invoke;

  Future<DriverDeliveryArrival> read(String orderId) =>
      _call('get_driver_delivery_arrival', {'p_order_id': orderId});
  Future<DriverDeliveryArrival> confirm(String orderId) =>
      _call('confirm_driver_delivery_arrival', {'p_order_id': orderId});
  Future<DriverDeliveryArrival> _call(
    String name,
    Map<String, dynamic> params,
  ) async {
    final result = await _invoke(
      name,
      params,
    ).timeout(const Duration(seconds: 15));
    return DriverDeliveryArrival.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }
}
