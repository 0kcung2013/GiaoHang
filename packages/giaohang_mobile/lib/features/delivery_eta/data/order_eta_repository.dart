import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_eta.dart';

typedef EtaInvoke = Future<dynamic> Function(String orderId);

class OrderEtaRepository {
  OrderEtaRepository({EtaInvoke? invoke})
    : _invoke =
          invoke ??
          ((orderId) async {
            final response = await Supabase.instance.client.functions.invoke(
              'refresh-order-eta',
              body: {'order_id': orderId},
            );
            return response.data;
          });
  final EtaInvoke _invoke;

  Future<OrderEta> refresh(String orderId) async {
    final json = await _invoke(orderId).timeout(const Duration(seconds: 15));
    return OrderEta.fromJson(Map<String, dynamic>.from(json as Map));
  }
}
