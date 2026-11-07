import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/order_model.dart';

final recipientHoldRepositoryProvider = Provider(
  (ref) => RecipientHoldRepository(),
);

class RecipientHoldRepository {
  Future<OrderModel> update(String orderId, {int? minutes}) async {
    final result = await Supabase.instance.client.rpc(
      'set_driver_recipient_hold',
      params: {'p_order_id': orderId, 'p_minutes': minutes},
    );
    return OrderModel.fromJson(
      Map<String, dynamic>.from(result['order'] as Map),
    );
  }

  Future<void> requestReturn(String orderId) async {
    await Supabase.instance.client.rpc(
      'request_recipient_hold_return',
      params: {'p_order_id': orderId},
    );
  }
}
