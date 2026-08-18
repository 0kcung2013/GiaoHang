import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class OrderReturnRepository {
  Future<OrderReturn?> fetchForOrder(String orderId);
  Future<(double, double)?> fetchIncidentOrigin(String riskReportId);
  Stream<OrderReturn?> watchForOrder(String orderId);
  Future<OrderReturn> startReturn(String orderId);
  Future<OrderReturn> confirmReturn({
    required String orderId,
    required String receiverName,
    String? note,
  });
}

class SupabaseOrderReturnRepository implements OrderReturnRepository {
  SupabaseOrderReturnRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<OrderReturn?> fetchForOrder(String orderId) async {
    final row = await _client
        .from('order_returns')
        .select()
        .eq('order_id', orderId)
        .maybeSingle();
    return row == null ? null : OrderReturn.fromJson(row);
  }

  @override
  Future<(double, double)?> fetchIncidentOrigin(String riskReportId) async {
    final row = await _client
        .from('risk_report_attachments')
        .select('latitude,longitude')
        .eq('risk_report_id', riskReportId)
        .eq('evidence_type', 'location')
        .order('captured_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final latitude = (row?['latitude'] as num?)?.toDouble();
    final longitude = (row?['longitude'] as num?)?.toDouble();
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return (latitude, longitude);
  }

  @override
  Stream<OrderReturn?> watchForOrder(String orderId) {
    return _client
        .from('order_returns')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .map((rows) => rows.isEmpty ? null : OrderReturn.fromJson(rows.first));
  }

  @override
  Future<OrderReturn> startReturn(String orderId) async {
    final response = await _client.rpc<Map<String, dynamic>>(
      'start_order_return',
      params: {'p_order_id': orderId},
    );
    return OrderReturn.fromJson(response);
  }

  @override
  Future<OrderReturn> confirmReturn({
    required String orderId,
    required String receiverName,
    String? note,
  }) async {
    final response = await _client.rpc<Map<String, dynamic>>(
      'confirm_order_return',
      params: {
        'p_order_id': orderId,
        'p_receiver_name': receiverName.trim(),
        'p_note': note?.trim(),
      },
    );
    return OrderReturn.fromJson(response);
  }
}
